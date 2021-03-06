#include "ruby.h"
#include "st.h"
#define GetCache(obj, ptr) Data_Get_Struct(obj, CouplerCache, ptr);

static ID    id_find, id_primary_key, id_select, id_next, id_close, id_reclaim,
             id_method, id_to_proc, id_define_finalizer, id_debug, id_count;
static VALUE sym_columns, sym_conditions, sym_offset, sym_limit;

VALUE rb_mCoupler;
VALUE rb_mCoupler_cResource;
VALUE rb_mCoupler_cCachedResource;
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

typedef struct CouplerCache_s {
  struct st_table *cache;
  struct st_table *rev_cache;
  VALUE resource;
  VALUE primary_key;
  VALUE reclaim_proc;
  VALUE keys;
  VALUE logger;
  long  guaranteed;
  long  live;
  long  fetches;
  long  misses;
  int   db_limit;
  guar *ghead;
  guar *gtail;
} CouplerCache;

typedef struct CacheEntry_s {
  VALUE data;
  int free;
} CacheEntry;

void
cache_mark(c)
  CouplerCache *c;
{
  int i;
  CacheEntry *e;
  guar *g;

  rb_gc_mark(c->resource);
  rb_gc_mark(c->primary_key);
  rb_gc_mark(c->reclaim_proc);
  rb_gc_mark(c->keys);
  rb_gc_mark(c->logger);

  /* mark values sometimes depending on number of objects */
  g = c->ghead;
  while (g) {
    rb_gc_mark(g->object);
    g = (guar *)g->next;
  }
}

void
do_clear(c)
  CouplerCache *c;
{
  struct st_table *hash;
  st_table_entry *ptr, *next;
  guar *g, *gtmp;
  int i;

  /* free up cache entries */
  hash = c->cache;
  while (1) {
    if (hash->num_entries > 0) {
      for (i = 0; i < hash->num_bins; i++) {
        ptr = hash->bins[i];
        while (ptr) {
          next = ptr->next;
          if (hash == c->cache)
            free((CacheEntry *)ptr->record);
          free(ptr);
          ptr = next; 
        }
        hash->bins[i] = 0;
      }
      hash->num_entries = 0;
    }

    if (hash == c->rev_cache)
      break;
    else
      hash = c->rev_cache;
  }

  /* free guaranteed list */
  g = c->ghead;
  while (g) {
    gtmp = (guar *)g->next;
    free(g);
    g = gtmp;
  }
  c->ghead = c->gtail = 0;
  c->live = 0;
}

void
cache_free(c)
  CouplerCache *c;
{
  do_clear(c);
  st_free_table(c->cache);
  st_free_table(c->rev_cache);
  free(c);
}

static VALUE
cache_alloc(klass)
  VALUE klass;
{
  CouplerCache *c = ALLOC(CouplerCache);
  c->resource     = Qnil;
  c->primary_key  = Qnil;
  c->reclaim_proc = Qnil;
  c->keys         = Qnil;
  c->fetches      = 0;
  c->misses       = 0;
  c->live         = 0;
  c->db_limit     = 0;
  c->cache        = st_init_numtable();
  c->rev_cache    = st_init_numtable();
  c->ghead        = 0;
  c->gtail        = 0;
  return Data_Wrap_Struct(klass, cache_mark, cache_free, c);
}

static VALUE
cache_init(self, resource_name, options)
  VALUE self;
  VALUE resource_name;
  VALUE options;
{
  CouplerCache *c;
  VALUE resource, method;

  GetCache(self, c);

  /* find resource */
  resource = rb_funcall(rb_mCoupler_cResource, id_find, 1, resource_name);

  /* initialize data */
  c->resource    = resource;
  c->primary_key = rb_funcall(resource, id_primary_key, 0);
  c->keys        = rb_ary_new();
  c->logger      = rb_funcall(rb_mCoupler, rb_intern("logger"), 0);
  c->db_limit    = FIX2INT(rb_funcall(options, rb_intern("db_limit"), 0));
  c->guaranteed  = FIX2INT(rb_funcall(options, rb_intern("guaranteed"), 0));

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
  CouplerCache *c;
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
  CouplerCache *c;
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
  CouplerCache *c;
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
  if (c->guaranteed > 0 && c->live <= c->guaranteed) {
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
  }
}

static VALUE
cache_add(self, key, value)
  VALUE self;
  VALUE key;
  VALUE value;
{
  CouplerCache *c;
  GetCache(self, c);
  do_add(c, key, value);
  rb_ary_store(c->keys, RARRAY(c->keys)->len, key);
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
  /* FIXME: add start/length support so that I don't have to do cache.fetch(cache.keys[10..20]) */
  VALUE retval, key, qry, res, select_args, key_str, inspect_ary, tmp, gc_was_off, ptr;
  unsigned long i, entry_l;
  int str_len;
  char *c_qry;
  CouplerCache *c;
  CacheEntry   *e;

  GetCache(self, c);
  c->fetches++;

  if ( RTEST(c->logger) ) {
    tmp = rb_str_plus(rb_str_new2("Fetching from cache: "), rb_inspect(args));
    rb_funcall(c->logger, id_debug, 1, tmp);
  }

  /* this may or may not be a bad idea.  it might be possible to rewrite
   * this function so that there's no new memory being allocated during the
   * fetching process.  i don't know that there's a huge advantage to doing
   * that, however. */
  gc_was_off = rb_gc_disable();

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
  CouplerCache *c;
  GetCache(self, c);
  return INT2FIX(c->fetches);
}

static VALUE
cache_misses(self)
  VALUE self;
{
  CouplerCache *c;
  GetCache(self, c);
  return INT2FIX(c->misses);
}

static VALUE
cache_count(self)
  VALUE self;
{
  CouplerCache *c;
  GetCache(self, c);
  return LONG2NUM(RARRAY(c->keys)->len); 
}

/*
 *  call-seq:
 *     cache.keys  -> array
 *  
 *  Returns array of keys in the order they were added to the cache.
 */
static VALUE
cache_keys(self)
  VALUE self;
{
  CouplerCache *c;
  GetCache(self, c);
  return c->keys;
}

static VALUE
cache_aref(self, offset)
  VALUE self;
  VALUE offset;
{
  CouplerCache *c;
  GetCache(self, c);
}

static VALUE
cache_clear(self)
  VALUE self;
{
  CouplerCache *c;
  GetCache(self, c);

  do_clear(c);
  rb_ary_clear(c->keys);
  return Qnil;
}

static VALUE
cache_auto_fill(self)
  VALUE self;
{
  VALUE select_args, tmp, key, res; 
  long count, offset;
  CouplerCache *c;
  GetCache(self, c);

  count = rb_funcall(c->resource, id_count, 0);

  /* construct select arguments hash */
  select_args = rb_hash_new();
  rb_gc_register_address(&select_args);    /* i don't know if this is good practice or not */
  rb_hash_aset(select_args, sym_columns, rb_ary_new3(2, c->primary_key, rb_str_new("*", 1)));
  rb_hash_aset(select_args, sym_limit, LONG2NUM(c->db_limit));

  offset = 0;
  while (offset < count) {
    /* get the result set */
    rb_hash_aset(select_args, sym_offset, INT2FIX(offset));
    res = rb_funcall(c->resource, id_select, 1, select_args);
    if (!RTEST(res))
      break;

    while ( RTEST(tmp = rb_funcall(res, id_next, 0)) ) {
      /* key is first element in tmp */
      key = rb_ary_shift(tmp);
      do_add(c, key, tmp);
      rb_ary_store(c->keys, RARRAY(c->keys)->len, key);
    }
    rb_funcall(res, id_close, 0);
    offset += c->db_limit;
  }

  rb_gc_unregister_address(&select_args);
  return Qnil;
}

void
Init_cached_resource()
{
  id_find        = rb_intern("find");
  id_primary_key = rb_intern("primary_key");
  id_select      = rb_intern("select");
  id_next        = rb_intern("next");
  id_close       = rb_intern("close");
  id_reclaim     = rb_intern("reclaim");
  id_method      = rb_intern("method");
  id_to_proc     = rb_intern("to_proc");
  id_debug       = rb_intern("debug");
  id_count       = rb_intern("count");
  id_define_finalizer = rb_intern("define_finalizer");
  sym_columns    = ID2SYM(rb_intern("columns"));
  sym_conditions = ID2SYM(rb_intern("conditions"));
  sym_limit      = ID2SYM(rb_intern("limit"));
  sym_offset     = ID2SYM(rb_intern("offset"));

  rb_mObSpace = rb_const_get(rb_cObject, rb_intern("ObjectSpace"));
  rb_mCoupler = rb_const_get(rb_cObject, rb_intern("Coupler"));
  rb_mCoupler_cResource = rb_const_get(rb_mCoupler, rb_intern("Resource"));
  
  rb_mCoupler_cCachedResource = rb_define_class_under(rb_mCoupler, "CachedResource", rb_cObject);
  rb_define_alloc_func(rb_mCoupler_cCachedResource, cache_alloc);
  rb_define_method(rb_mCoupler_cCachedResource, "initialize", cache_init, 2);
  rb_define_method(rb_mCoupler_cCachedResource, "add", cache_add, 2);
  rb_define_method(rb_mCoupler_cCachedResource, "fetch", cache_fetch, -2);
  rb_define_method(rb_mCoupler_cCachedResource, "fetches", cache_fetches, 0);
  rb_define_method(rb_mCoupler_cCachedResource, "misses", cache_misses, 0);
  rb_define_method(rb_mCoupler_cCachedResource, "count", cache_count, 0);
  rb_define_method(rb_mCoupler_cCachedResource, "keys", cache_keys, 0);
  rb_define_method(rb_mCoupler_cCachedResource, "clear", cache_clear, 0);
  rb_define_method(rb_mCoupler_cCachedResource, "auto_fill!", cache_auto_fill, 0);
  rb_define_private_method(rb_mCoupler_cCachedResource, "reclaim", cache_reclaim, 1);
}
