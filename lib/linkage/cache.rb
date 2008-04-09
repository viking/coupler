# NOTE: thanks to eigenclass.org for ideas on this
module Linkage
  class Cache
    attr_reader :misses, :fetches

    def initialize(resource_name)
      @resource  = Linkage::Resource.find(resource_name)
      @cache     = Hash.new 
      @misses    = 0
      @fetches   = 0
    end

    def add(key, record)
      @cache[key] = WeakRef.new(record)
      record
    end

    def fetch(key)
      @fetches += 1
      record = @cache[key]
      unless record.weakref_alive?
        # re-fetch the row
        @misses += 1
        record = add(key, @resource.select_one(key))
      end
      record
    end

    def size
      [@cache.size, @rev_cache.size]
    end

    def keys
      @cache.keys
    end
  end
end
