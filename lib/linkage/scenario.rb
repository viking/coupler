module Linkage
  class Scenario
    DEBUG = ENV['DEBUG']

    attr_reader :name, :type
    def initialize(options)
      @name = options['name']
      @type = options['type']
      @guarantee = options['guarantee']

      case @type
      when 'self-join'
        @resources = [Linkage::Resource.find(options['resource'])]
        raise "can't find resource '#{options['resource']}'"   unless @resources[0]
      end
      @scratch = Linkage::Resource.find('scratch')
      @cache = @guarantee ? Linkage::Cache.new('scratch', @guarantee) : Linkage::Cache.new('scratch')

      # grab list of fields
      matcher_fields     = options['matchers'].collect { |m| m['field'] }
      transformer_fields = if options['transformations']
        then options['transformations'].collect { |t| t['arguments'].values }.flatten
        else []
      end
      @field_list = (matcher_fields + transformer_fields).uniq
      @field_list.unshift(@resources[0].primary_key)  if @type == 'self-join'

      # grab scoring groups
      @groups = options['scoring']['groups'].inject({}) do |hsh, (key, value)|
        hsh[key] = value.is_a?(Range) ? value : eval(value)
        hsh
      end

      # setup matchers
      @master_matcher = Linkage::Matchers::MasterMatcher.new({
        'field list'       => @field_list,
        'combining method' => options['scoring']['combining method'],
        'groups'           => @groups,
        'cache'            => @cache,
        'resource'         => @scratch
      })
      options['matchers'].each { |m| @master_matcher.add_matcher(m) }

      # grab transformers
      @transformations = []
      options['transformations'].each do |info|
        next  unless matcher_fields.include?(info['name'])

        t = Linkage::Transformer.find(info['transformer'])
        raise "can't find transformer '#{info['transformer']}'"  unless t
        info['transformer'] = t
        @transformations << info
      end if options['transformations']

      # other
      @conditions = options['blocking']
      @limit = options['limit']  # undocumented and untested, wee!
    end

    def run
      @cache.clear
      Linkage.logger.info("Scenario (#{name}): Run start")  if Linkage.logger

      case @type
      when 'self-join'
        resource = @resources[0]
        primary_key = resource.primary_key

        # select records
        @num_records   = @limit ? @limit : resource.count.to_i
        @record_offset = 0
        progress = Progress.new(@num_records)   if DEBUG
        record_set = grab_records(resource)

        # grab first record and do transformations so that we know how
        # to setup the scratch database
        record = transform(record_set.next)
        record_id = record[0]

        # setup scratch database
        schema = []
        @field_list.each_with_index do |field, i|
          case record[i]
          when Fixnum, Bignum
            schema << "#{field} int"
          when String
            schema << "#{field} varchar(255)"
          else
          end
        end
        @scratch.drop_table(resource.table)
        @scratch.create_table(resource.table, *schema)
        @scratch.insert(@field_list, record)
        @cache.add(record_id, record)
        ids = [record_id]

        # transform all records first
        while(true) do
          record = record_set.next
          if record.nil?
            # grab next set of records, or quit
            record_set.close
            record_set = grab_records(resource)
            if record_set 
              record = record_set.next
            else
              break
            end
          end

          record    = transform(record)
          record_id = record[0]
          @scratch.insert(@field_list, record)  # save in database
          @cache.add(record_id, record)         # save in cache
          ids << record_id
        end

        # now match!
        retval = @master_matcher.score

        if DEBUG
          puts "*** Cache summary ***"
          puts "Fetches: #{@cache.fetches}"
          puts "Misses:  #{@cache.misses}"
        end

        retval
      end
    end

    private
      def grab_records(resource)
        if @num_records > 0 
          limit = @limit && @limit < 1000 ? @limit : 1000
          if @conditions
            set = resource.select({
              :limit => limit, :columns => @field_list, :conditions => @conditions,
              :offset => @record_offset
            })
          else
            args = @field_list + [{:offset => @record_offset}]  # this is a bit silly
            set = resource.select_num(limit, *args)
          end
          @num_records   -= 1000 
          @record_offset += 1000
          return set
        end
        nil
      end

      def transform(record)
        @transformations.each do |info|
          transformer = info['transformer']
          field = info['name']
          args = info['arguments'].inject({}) do |args, (key, val)|
            index = @field_list.index(val)
            args[key] = record[index]
            args
          end
          record[@field_list.index(field)] = transformer.transform(args)
        end
        record
      end
  end
end
