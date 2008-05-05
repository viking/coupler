#include "ruby.h"
#include "st.h"
#define GetCache(obj, ptr) Data_Get_Struct(obj, LinkageCache, ptr);

static ID    id_find, id_primary_key, id_select, id_next, id_close, id_reclaim,
             id_method, id_to_proc, id_define_finalizer;
static VALUE sym_columns, sym_conditions;

VALUE rb_mLinkage;
VALUE rb_mLinkage_cResource;
VALUE rb_mLinkage_cCache;
VALUE rb_mObSpace;

/* copied from st.c; I have no idea why it's not in st.h */
typedef struct st_table_entry st_table_entry;

struct st_table_entry {
  unsigned int hash;
  st_data_t key;
  st_data_t record;
  st_table_entry *next;
};

typedef struct guar_s {
  VALUE object;
  void *next;
} guar;

typedef struct LinkageCache_s {
  struct st_table *cache;
  struct st_table *rev_cache;
  VALUE resource;
  VALUE primary_key;
  VALUE reclaim_proc;
  long  guaranteed;
  long  live;
  long  fetches;
  long  misses;
  guar *ghead;
  guar *gtail;
} LinkageCache;

typedef struct CacheEntry_s {
  VALUE data;
  int free;
} CacheEntry;

void
cache_mark(c)
  LinkageCache *c;
{
  int i;
  CacheEntry *e;
  guar *g;

  rb_gc_mark(c->resource);
  rb_gc_mark(c->primary_key);
  rb_gc_mark(c->reclaim_proc);

  /* mark values sometimes depending on number of objects */
  g = c->ghead;
  while (g) {
    rb_gc_mark(g->object);
    g = (guar *)g->next;
  }
}

void
cache_free(c)
  LinkageCache *c;
{
  st_table_entry *tbl_entry;
  guar *g, *gtmp;
  int i;

  /* free up cache entries */
  if (c->cache->num_entries > 0) {
    for (i = 0; i < c->cache->num_bins; i++) {
      tbl_entry = c->cache->bins[i];
      while (tbl_entry) {
        free((CacheEntry *)tbl_entry->record);
        tbl_entry = tbl_entry->next;
      }
    }
  }
  st_free_table(c->cache);
  st_free_table(c->rev_cache);

  /* free guaranteed list */
  g = c->ghead;
  while (g) {
    gtmp = (guar *)g->next;
    free(g);
    g = gtmp;
  }

  free(c);
}

static VALUE
cache_alloc(klass)
  VALUE klass;
{
  LinkageCache *c = ALLOC(LinkageCache);
  c->resource     = Qnil;
  c->primary_key  = Qnil;
  c->reclaim_proc = Qnil;
  c->fetches      = 0;
  c->misses       = 0;
  c->live         = 0;
  c->cache        = st_init_numtable();
  c->rev_cache    = st_init_numtable();
  c->ghead        = 0;
  c->gtail        = 0;
  return Data_Wrap_Struct(klass, cache_mark, cache_free, c);
}

static VALUE
cache_init(argc, argv, self)
  int    argc;
  VALUE *argv;
  VALUE  self;
{
  LinkageCache *c;
  VALUE resource_name, guaranteed, resource, method;

  GetCache(self, c);
  if (rb_scan_args(argc, argv, "11", &resource_name, &guaranteed)) {
    if (!NIL_P(guaranteed)) {
      if (!FIXNUM_P(guaranteed))
        rb_raise(rb_eTypeError, "wrong argument type %s (expected Fixnum)", rb_obj_classname(guaranteed));

      c->guaranteed = FIX2INT(guaranteed);
    }
    else {
      c->guaranteed = 0;
    }
  }

  /* find resource */
  resource = rb_funcall(rb_mLinkage_cResource, id_find, 1, resource_name);

  /* initialize data */
  c->resource    = resource;
  c->primary_key = rb_funcall(resource, id_primary_key, 0);

  /* make the reclaim proc.  this is kinda ghetto */
  method = rb_funcall(self, id_method, 1, ID2SYM(id_reclaim));
  c->reclaim_proc = rb_funcall(method, id_to_proc, 0);

  return self;
}

static VALUE
cache_reclaim(self, object_id)
  VALUE self;
  VALUE object_id;
{
  VALUE key;
  LinkageCache *c;
  CacheEntry   *e;
  GetCache(self, c);

  /* this is false in cases where finalizers weren't called directly after GC */
  if (st_delete(c->rev_cache, (st_data_t *)&object_id, (st_data_t *)&key)) {
    /* get entry from real cache */
    if (st_lookup(c->cache, (st_data_t)key, (st_data_t *)&e)) {
      e->free = 1;
      c->live--;
    }
  }

  return Qnil;
}

static void
cache_reclaim2(c, e, obj)
  LinkageCache *c;
  CacheEntry   *e;
{
  VALUE object_id;

  object_id = rb_obj_id(e->data);
  st_delete(c->rev_cache, (st_data_t *)&object_id, 0);
  e->free = 1;
  c->live--;
}

static void
do_add(c, key, value)
  LinkageCache *c;
  VALUE key;
  VALUE value;
{
  VALUE objid;
  long entry_l;
  int  dont_add;
  CacheEntry *e;
  guar *g, *gtmp;

  /* see if there's an entry already */
  if (dont_add = st_lookup(c->cache, (st_data_t)key, (st_data_t *)&entry_l)) {
    e = (CacheEntry *)entry_l;
  } else {
    e = ALLOC(CacheEntry);
  }
  e->free = 0;
  e->data = value;
  objid   = rb_obj_id(value);

  /* add reclaim finalizer */
  rb_funcall(rb_mObSpace, id_define_finalizer, 2, value, c->reclaim_proc);

  /* insert entry into cache */
  st_insert(c->rev_cache, (st_data_t)objid, (st_data_t)key);  /* one key per id in this case */
  if (!dont_add)
    st_add_direct(c->cache, (st_data_t)key, (st_data_t)e);

  /* handle guaranteeing */
  c->live++;
  if (c->guaranteed > 0) {
    guar *g = ALLOC(guar);
    g->object = value;
    g->next   = NULL;
    if (c->gtail) {
      c->gtail->next = (void *)g;
      c->gtail = g; 
    }
    else {
      c->ghead = c->gtail = g;
    }

    if (c->live > c->guaranteed) {
      /* take off front */
      gtmp     = (guar *)c->ghead;
      c->ghead = (guar *)c->ghead->next;
      free(gtmp);
    }
  }
}

static VALUE
cache_add(self, key, value)
  VALUE self;
  VALUE key;
  VALUE value;
{
  LinkageCache *c;
  GetCache(self, c);
  do_add(c, key, value);
  return value;
}

/*
 *  call-seq:
 *     cache.fetch(id1, id2, ...)  -> array
 *  
 *  Fetch value(s) from the cache.  First element can also be an array
 *  of keys to fetch.
 *
 *  NOTE: values are not guaranteed to be the same order that you requested!
 */

static VALUE
cache_fetch(self, args)
  VALUE self;
  VALUE args;
{
  VALUE retval, key, qry, res, select_args, key_str, inspect_ary, tmp, gc_was_off, ptr;
  unsigned long i, entry_l;
  int str_len;
  char *c_qry;
  LinkageCache *c;
  CacheEntry   *e;

  /* this may or may not be a bad idea.  it might be possible to rewrite
   * this function so that there's no new memory being allocated during the
   * fetching process.  i don't know that there's a huge advantage to doing
   * that, however. */
  gc_was_off = rb_gc_disable();

  GetCache(self, c);
  c->fetches++;

  /* determine how to return result */
  retval = Qnil;
  if (RARRAY(args)->len == 1) {
    tmp = rb_ary_entry(args, 0);
    if (TYPE(tmp) == T_ARRAY) {
      args = tmp; 
      retval = rb_ary_new2(RARRAY(args)->len);
    }
  }
  else
    retval = rb_ary_new2(RARRAY(args)->len);

  /* iterate through array of keys; collecting bad keys for recovery */
  inspect_ary = rb_ary_new();
  res = Qnil;
  for (i = 0; i < RARRAY(args)->len; i++) {
    key = rb_ary_entry(args, i);
    if (!st_lookup(c->cache, (st_data_t)key, (st_data_t *)&entry_l)) {
      /* This means that there was no entry for 'key' to begin with */
      if (retval == Qnil)
        goto all_done;

      rb_ary_push(retval, Qnil); 
      continue;
    }
    e = (CacheEntry *)entry_l;

    /* IMPORTANT! finalizers sometimes aren't called right after GC */
    if (BUILTIN_TYPE(e->data) == 0 || RBASIC(e->data)->klass == 0) {
      /* object has been recycled, but not finalized */
      cache_reclaim2(c, e);
    }

    /* If e->free is 1 at this point, it means the object was GC'd */
    if (e->free == 1) {
      c->misses++;
      rb_ary_push(inspect_ary, rb_inspect(key));
    }
    else {
      if (retval == Qnil) {
        retval = e->data;
        goto all_done;
      }
      rb_ary_push(retval, e->data); 
    }
  }

  /* recover bad keys from the resource */
  if (RARRAY(inspect_ary)->len > 0) {
    /* construct select arguments hash */
    /* TODO: add C interface for Resource#select? */
    select_args = rb_hash_new();
    rb_hash_aset(select_args, sym_columns, rb_ary_new3(2, c->primary_key, rb_str_new("*", 1)));

    /* make query string: "WHERE ID IN (1, 2, 3, ...)" */
    key_str = rb_ary_join(inspect_ary, rb_str_new(", ", 2)); 
    str_len = 12 + RSTRING_LEN(c->primary_key) + RSTRING_LEN(key_str);
    c_qry   = ALLOC_N(char, str_len+1);
    sprintf(c_qry, "WHERE %s IN (%s)", RSTRING_PTR(c->primary_key), RSTRING_PTR(key_str));
    rb_hash_aset(select_args, sym_conditions, rb_str_new(c_qry, str_len));
    free(c_qry);

    /* get the result set */
    res = rb_funcall(c->resource, id_select, 1, select_args);
    
    /* re-insert objects into cache */ 
    while ( RTEST(tmp = rb_funcall(res, id_next, 0)) ) {
      /* key is first element in tmp */
      key = rb_ary_shift(tmp);
      do_add(c, key, tmp);

      /* return accordingly */
      if (retval == Qnil) {
        retval = tmp;
        goto all_done;
      }
      rb_ary_push(retval, tmp); 
    }
    rb_funcall(res, id_close, 0);
  }

  all_done:
    if (!RTEST(gc_was_off))
      rb_gc_enable();

    if (!NIL_P(res))
      rb_funcall(res, id_close, 0);

    return retval;
}

static VALUE
cache_fetches(self)
  VALUE self;
{
  LinkageCache *c;
  GetCache(self, c);
  return INT2FIX(c->fetches);
}

static VALUE
cache_misses(self)
  VALUE self;
{
  LinkageCache *c;
  GetCache(self, c);
  return INT2FIX(c->misses);
}

void
Init_cache()
{
  id_find        = rb_intern("find");
  id_primary_key = rb_intern("primary_key");
  id_select      = rb_intern("select");
  id_next        = rb_intern("next");
  id_close       = rb_intern("close");
  id_reclaim     = rb_intern("reclaim");
  id_method      = rb_intern("method");
  id_to_proc     = rb_intern("to_proc");
  id_define_finalizer = rb_intern("define_finalizer");
  sym_columns    = ID2SYM(rb_intern("columns"));
  sym_conditions = ID2SYM(rb_intern("conditions"));

  rb_mObSpace = rb_const_get(rb_cObject, rb_intern("ObjectSpace"));
  rb_mLinkage = rb_const_get(rb_cObject, rb_intern("Linkage"));
  rb_mLinkage_cResource = rb_const_get(rb_mLinkage, rb_intern("Resource"));
  
  rb_mLinkage_cCache = rb_define_class_under(rb_mLinkage, "Cache", rb_cObject);
  rb_define_alloc_func(rb_mLinkage_cCache, cache_alloc);
  rb_define_method(rb_mLinkage_cCache, "initialize", cache_init, -1);
  rb_define_method(rb_mLinkage_cCache, "add", cache_add, 2);
  rb_define_method(rb_mLinkage_cCache, "fetch", cache_fetch, -2);
  rb_define_method(rb_mLinkage_cCache, "fetches", cache_fetches, 0);
  rb_define_method(rb_mLinkage_cCache, "misses", cache_misses, 0);
  rb_define_private_method(rb_mLinkage_cCache, "reclaim", cache_reclaim, 1);
}
