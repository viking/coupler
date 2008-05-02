#include "ruby.h"
#define GetCache(obj, ptr) Data_Get_Struct(obj, LinkageCache, ptr);
#define GetRecord(obj, ptr) Data_Get_Struct(obj, CacheRecord, ptr);

static ID    id_find, id_primary_key, id_select, id_next;
static VALUE sym_columns, sym_conditions;

VALUE rb_mLinkage;
VALUE rb_mLinkage_cResource;
VALUE rb_mLinkage_cCache;
VALUE rb_mLinkage_cCache_cRecord;

typedef struct LinkageCache_s {
  VALUE cache;
  VALUE resource;
  VALUE primary_key;
  long  fetches;
  long  misses;
} LinkageCache;

typedef struct CacheRecord_s {
  VALUE key;
  VALUE value;
  VALUE cache;
} CacheRecord;

void
cache_mark(c)
  LinkageCache *c;
{
  rb_gc_mark(c->cache);
  rb_gc_mark(c->resource);
  rb_gc_mark(c->primary_key);
}

void
cache_free(c)
  LinkageCache *c;
{
  free(c);
}

void
record_free(r)
  CacheRecord *r;
{
  /* tell the cache that I've been garbage collected */
//  printf("%d got garbage collected!\n", FIX2INT(r->key));
  rb_hash_aset(r->cache, r->key, Qnil); 
  free(r);
}

static VALUE
cache_alloc(klass)
  VALUE klass;
{
  LinkageCache *c = ALLOC(LinkageCache);
  c->cache        = Qnil;
  c->resource     = Qnil;
  c->fetches      = 0;
  c->misses       = 0;
  return Data_Wrap_Struct(klass, cache_mark, cache_free, c);
}

static VALUE
cache_init(self, resource_name)
  VALUE self;
  VALUE resource_name;
{
  LinkageCache *c;
  VALUE resource;

  /* find resource */
  resource = rb_funcall(rb_mLinkage_cResource, id_find, 1, resource_name);

  /* initialize data */
  GetCache(self, c);
  c->cache       = rb_hash_new();
  c->resource    = resource;
  c->primary_key = rb_funcall(resource, id_primary_key, 0);

  return self;
}

static VALUE
record_init(self)
  VALUE self;
{
  rb_raise(rb_eRuntimeError, "I'm only meant for internal use!");
  return Qnil;
}

static void
do_add(c, key, value)
  LinkageCache *c;
  VALUE key;
  VALUE value;
{
  VALUE obj, object_id; 
  CacheRecord *r;

  /* Make a Linkage::Cache::Record object to store. The reason for this
   * is so that the Record can modify the cache when it gets garbage
   * collected. */

  r = ALLOC(CacheRecord);
  r->cache = c->cache;
  r->value = value;
  r->key   = key;
  obj = Data_Wrap_Struct(rb_mLinkage_cCache_cRecord, 0, record_free, r);

  object_id = rb_obj_id(obj);
  rb_hash_aset(c->cache, key, object_id);
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
  VALUE object_id, retval, key, select_args, qry, key_str, res, inspect_ary, tmp, ptr, gc;
  unsigned long i, bad_count;
  int str_len;
  char *c_qry;
  LinkageCache *c;
  CacheRecord *r;

  /* this may or may not be a bad idea.  it's most likely possible to rewrite
   * this function so that there's no new memory being allocated during the
   * fetching process.  i don't know that there's a huge advantage to doing
   * that, however. */
  gc = rb_gc_disable();

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
  bad_count   = 0;
  for (i = 0; i < RARRAY(args)->len; i++) {
    key = rb_ary_entry(args, i);
    if (!st_lookup(RHASH(c->cache)->tbl, key, &object_id)) {
      /* This means that there was no entry for 'key' to begin with */
      if (retval == Qnil)
        return Qnil;

      rb_ary_push(retval, Qnil); 
      continue;
    }

    /* If object_id is nil at this point, it means the object was GC'd */
    if (NIL_P(object_id)) {
      c->misses++;
      bad_count++;
      rb_ary_push(inspect_ary, rb_inspect(key));
    }
    else {
      /* convert object id to a pointer; see id2ref in gc.c */
      ptr = (VALUE)(object_id ^ FIXNUM_FLAG);
      GetRecord(ptr, r)

      if (retval == Qnil)
        return r->value;
      rb_ary_push(retval, r->value); 
    }
  }

  /* recover bad keys from the resource */
  if (bad_count > 0) {
    /* construct select arguments hash */
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
      if (retval == Qnil)
        return tmp;
      rb_ary_push(retval, tmp); 
    }
  }

  if (!RTEST(gc))
    rb_gc_disable();

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
  sym_columns    = ID2SYM(rb_intern("columns"));
  sym_conditions = ID2SYM(rb_intern("conditions"));

  rb_mLinkage = rb_const_get(rb_cObject, rb_intern("Linkage"));
  rb_mLinkage_cResource = rb_const_get(rb_mLinkage, rb_intern("Resource"));
  rb_mLinkage_cCache = rb_define_class_under(rb_mLinkage, "Cache", rb_cObject);
  rb_mLinkage_cCache_cRecord = rb_define_class_under(rb_mLinkage_cCache, "Record", rb_cObject);
  
  rb_define_alloc_func(rb_mLinkage_cCache, cache_alloc);
  rb_define_method(rb_mLinkage_cCache, "initialize", cache_init, 1);
  rb_define_method(rb_mLinkage_cCache, "add", cache_add, 2);
  rb_define_method(rb_mLinkage_cCache, "fetch", cache_fetch, -2);
  rb_define_method(rb_mLinkage_cCache, "fetches", cache_fetches, 0);
  rb_define_method(rb_mLinkage_cCache, "misses", cache_misses, 0);

  rb_mLinkage_cCache_cRecord = rb_define_class_under(rb_mLinkage_cCache, "Record", rb_cObject);
  rb_define_method(rb_mLinkage_cCache_cRecord, "initialize", record_init, 0);
}