# NOTE: thanks to eigenclass.org for ideas on this
module Linkage
  class Cache
    attr_reader :misses, :fetches

    def initialize(resource_name)
      @resource  = Linkage::Resource.find(resource_name)
      @cache     = Hash.new 
      @rev_cache = Hash.new
      @misses    = 0
      @fetches   = 0
      @reclaim   = lambda do |value_id|
        # delete key from @cache when value gets GC'd
        if @rev_cache.has_key?(value_id)
          key = @rev_cache[value_id]
          @cache[key] = :gone
          @rev_cache.delete(value_id)
        end
      end
    end

    def add(key, record)
      id = record.object_id 
      @cache[key]    = id
      @rev_cache[id] = key
      ObjectSpace.define_finalizer(record, @reclaim)
      record
    end

    def fetch(*keys)
      @fetches += 1
      keys.flatten!

      # collect data, finding missing keys as we go along
      records = {} 
      missed  = []
      keys.each do |key|
        id = @cache[key]
        case id
        when nil
          records[key] = nil
        when :gone
          missed << key
        else
          begin
            records[key] = ObjectSpace._id2ref(id)
          rescue RangeError
            missed << key
          end
        end
      end

      # recover keys
      unless missed.empty?
        @misses += missed.length

        conditions = "WHERE #{@resource.primary_key} IN (#{missed.collect { |k| k.inspect }.join(", ")})"
        set = @resource.select(:conditions => conditions, :columns => [@resource.primary_key, "*"])
        while (record = set.next)
          id = record.shift
          records[id] = record
          add(id, record)
        end
      end

      keys.length == 1 ? records[keys.first] : records
    end

    def size
      [@cache.size, @rev_cache.size]
    end

    def keys
      @cache.keys
    end
  end
end
