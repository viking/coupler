module Linkage
  class Scenario
    DEBUG = ENV['DEBUG']

    attr_reader :name, :type
    def initialize(spec, options)
      @options = options
      @name = spec['name']
      @type = spec['type']
      @guarantee = spec['guarantee']
      @range = (r = spec['scoring']['range']).is_a?(Range) ? r : eval(r)

      case @type
      when 'self-join'
        @resource = Linkage::Resource.find(spec['resource'])
        raise "can't find resource '#{spec['resource']}'"   unless @resource
        @primary_key = @resource.primary_key
      else
        raise "unsupported scenario type"
      end
      @scratch = Linkage::Resource.find('scratch')
      @scores  = Linkage::Resource.find('scores')
      @cache   = if @guarantee then Linkage::Cache.new('scratch', options, @guarantee)
                 else Linkage::Cache.new('scratch', options) end

      # grab fields and transformers
      # NOTE: matcher fields can either be real database columns or the resulting field of
      #       a transformation (which can be named the same thing as the real database
      #       column).  because of that, transformer field types override those in the
      #       actual database.  i only care about field types that actually end up in the
      #       scratch database, so i'm not collecting types from the transformer
      #       arguments.
      matcher_fields   = spec['matchers'].collect { |m| m['field'] }
      @resource_fields = [@primary_key] + matcher_fields.dup   # fields i need to pull from the main resource
      @field_list      = [@primary_key] + matcher_fields.dup   # fields that will end up in scratch
      @field_info      = @resource.columns(@field_list)
      @transformations = {}
      spec['transformations'].each do |info|
        name, tname = info.values_at('name', 'transformer')
        next unless matcher_fields.include?(name)

        # adjust resource fields accordingly
        @resource_fields.delete(name)
        @resource_fields.push(*info['arguments'].values)

        t = Linkage::Transformer.find(tname)
        raise "can't find transformer '#{tname}'"  unless t
        @field_info[name] = t.data_type
        info['transformer'] = t
        @transformations[name] = info
      end if spec['transformations']
      @transform_buffer = []

      # setup matchers
      @master_matcher = Linkage::Matchers::MasterMatcher.new({
        'field list'       => @field_list,
        'combining method' => spec['scoring']['combining method'],
        'range'            => @range,
        'cache'            => @cache,
        'resource'         => @scratch,
        'scores'           => @scores,
        'name'             => @name 
      }, @options)
      @index_on  = []
      @use_cache = false
      spec['matchers'].each do |m|
        case m['type']
        when 'exact'
          @index_on << m['field']
        else
          @use_cache = true
        end
        @master_matcher.add_matcher(m)
      end

      # other
      @conditions = spec['conditions']
      @limit = spec['limit']  # undocumented and untested, wee!
    end

    def run
      return  if @options.dry_run

      @cache.clear
      Linkage.logger.info("Scenario (#{name}): Run start")  if Linkage.logger

      case @type
      when 'self-join'
        # select records
        @num_records   = @limit ? @limit : @resource.count.to_i
        @record_offset = 0
        record_set = grab_records

        # setup scratch database
        if @options.use_existing_scratch
          @cache.auto_fill!   if @use_cache
          @scratch.set_table_and_key(@resource.table, @resource.primary_key)
        else
          schema = []
          @field_list.each do |field|
            schema << "#{field} #{@field_info[field]}"
          end
          @scratch.drop_table(@resource.table)
          @scratch.create_table(@resource.table, schema, @index_on)

          # transform all records
          Linkage.logger.info("Scenario (#{name}): Transforming records")  if Linkage.logger
          while(true) do
            record = record_set.next
            if record.nil?
              # grab next set of records, or quit
              record_set.close
              record_set = grab_records
              if record_set 
                record = record_set.next
              else
                break
              end
            end

            record    = do_transformation(record)
            record_id = record[0]
            @cache.add(record_id, record)   if @use_cache

            @transform_buffer << record
            if @transform_buffer.length == @options.db_limit
              @scratch.insert(@field_list, *@transform_buffer)  # save in database
              @transform_buffer.clear
            end
          end
        end
        @scratch.insert(@field_list, *@transform_buffer)  unless @transform_buffer.empty?

        # now match!
        Linkage.logger.info("Scenario (#{name}): Matching records")  if Linkage.logger
        retval = @master_matcher.score

        if DEBUG
          puts "*** Cache summary ***"
          puts "Fetches: #{@cache.fetches}"
          puts "Misses:  #{@cache.misses}"
        end

        if @options.csv_output
          FasterCSV.open("#{@name}.csv", "w") do |csv|
            csv << %w{id1 id2 score}
            retval.each do |id1, id2, score|
              csv << [id1, id2, score]
            end
          end
        end
      end
    end

    private
      def grab_records
        if @num_records > 0 
          limit = @limit && @limit < @options.db_limit ? @limit : @options.db_limit 
          if @conditions
            set = @resource.select({
              :limit => limit, :columns => @resource_fields, :conditions => @conditions,
              :offset => @record_offset, :order => @primary_key
            })
          else
            set = @resource.select({
              :columns => @resource_fields, :limit => limit,
              :offset => @record_offset, :order => @primary_key
            })
          end
          @num_records   -= @options.db_limit 
          @record_offset += @options.db_limit
          return set
        end
        nil
      end

      # Transform a record, returning an array for the scratch database
      def do_transformation(record)
        @field_list.collect do |field|
          if (info = @transformations[field])
            transformer = info['transformer']
            args = info['arguments'].inject({}) do |args, (key, val)|
              index = @resource_fields.index(val)
              args[key] = record[index]
              args
            end
            transformer.transform(args)
          else
            record[@resource_fields.index(field)]
          end
        end
      end
  end
end
