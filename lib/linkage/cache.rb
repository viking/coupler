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

    def fetch(key)
      @fetches += 1
      begin
        old_critical = Thread.critical
        Thread.critical = true

        id = @cache[key]
        case id
        when :gone
          record = recover(key)
        when nil
          record = nil
        else
          begin
            record = ObjectSpace._id2ref(id)
          rescue RangeError
            record = recover(key)
          end
        end
      rescue Exception => boom
        debugger
        puts "error!"
      ensure
        Thread.critical = old_critical
      end

      record
    end

    def size
      [@cache.size, @rev_cache.size]
    end

    def keys
      @cache.keys
    end

    private
      def recover(key)
        @misses += 1
        add(key, @resource.select_one(key))
      end
  end
end
