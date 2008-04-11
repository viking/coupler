module Linkage
  class Scenario
    class Matcher
      attr_reader :field
      def initialize(options)
        @field = options['field']
        @formula = options['formula']
        self.instance_eval(<<-EOF, __FILE__, __LINE__)
          def score(a, b)
            #{@formula}
          end
        EOF
      end
    end

    DEBUG = ENV['DEBUG']

    attr_reader :name, :type
    def initialize(options)
      options = HashWithIndifferentAccess.new(options)
      @name = options[:name]
      @type = options[:type]

      case @type
      when 'self-join'
        @resources = [Linkage::Resource.find(options[:resource])]
        raise "can't find resource '#{options[:resource]}'"   unless @resources[0]
      end
      @scratch = Linkage::Resource.find('scratch')

      matcher_fields = []
      @matchers = options[:matchers].collect do |config|
        matcher_fields << config['field']
        Matcher.new(config)
      end

      @transformations = []
      xform_fields     = []
      options[:transformations].each do |info|
        next  unless matcher_fields.include?(info['name'])

        xform_fields.push(*info['arguments'].values)
        t = Linkage::Transformer.find(info['transformer'])
        raise "can't find transformer '#{info['transformer']}'"  unless t
        info['transformer'] = t
        @transformations << info
      end if options[:transformations]

      # scoring stuff
      @scoring = options[:scoring]
      @scoring[:groups] = @scoring[:cutlist].keys.sort
      @scoring[:ranges] = @scoring[:groups].collect { |n| eval(@scoring[:cutlist][n]) }
      self.instance_eval(<<-EOF, __FILE__, __LINE__)
        def combine_scores(scores)
          #{@scoring[:formula]}
        end
      EOF
      
      @all_fields = (matcher_fields + xform_fields).uniq
      @all_fields.unshift(@resources[0].primary_key)  if @type == 'self-join'

      @conditions = options[:blocking]
      @limit = options[:limit]  # undocumented and untested, wee!
    end

    def run
      retval = @scoring[:groups].inject({}) { |hsh, name| hsh[name] = []; hsh }

      case @type
      when 'self-join'
        resource = @resources[0]
        primary_key = resource.primary_key

        # select records
        @num_records   = @limit ? @limit : resource.count.to_i
        @record_offset = 0
        progress = Progress.new(@num_records)   if DEBUG
        record_set = grab_records(resource)

        # grab first record and do transformations
        record = transform(record_set.next)
        record_id = record[0]

        # setup scratch database
        schema = []
        @all_fields.each_with_index do |field, i|
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

        # setup cache
        cache = Linkage::Cache.new('scratch')
        ids   = []

        # first pass; transform records, put in scratch database, match record to first
        progress.next   if DEBUG
        while(true) do
          candidate = record_set.next
          if candidate.nil?
            # grab next set of records, or quit
            record_set.close
            record_set = grab_records(resource)
            if record_set 
              candidate = record_set.next
            else
              break
            end
          end

          candidate = transform(candidate)
          candidate_id = candidate[0]
          @scratch.insert(@all_fields, candidate)   # save in database
          cache.add(candidate_id, candidate)        # save in cache
          ids << candidate_id

          # match records
          group, score = match(record, candidate)
          retval[group] << [record_id, candidate_id, score] if group
        end

        # now match the rest of the records
        ids.each_with_index do |record_id, i|
          progress.next   if DEBUG
          record = cache.fetch(record_id)
          ids[i+1..-1].each do |candidate_id|
            candidate = cache.fetch(candidate_id)

            # match records
            group, score = match(record, candidate)
            retval[group] << [record_id, candidate_id, score] if group
          end
        end

        if DEBUG
          puts "*** Cache summary ***"
          puts "Fetches: #{cache.fetches}"
          puts "Misses:  #{cache.misses}"
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
              :limit => limit, :columns => @all_fields, :conditions => @conditions,
              :offset => @record_offset
            })
          else
            args = @all_fields + [{:offset => @record_offset}]  # this is a bit silly
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
            index = @all_fields.index(val)
            args[key] = record[index]
            args
          end
          record[@all_fields.index(field)] = transformer.transform(args)
        end
        record
      end

      def match(record, candidate)
        scores = []
        @matchers.each do |matcher|
          index = @all_fields.index(matcher.field)
          scores << matcher.score(record[index], candidate[index])
        end

        # combine scores
        final_score = combine_scores(scores)
        @scoring[:ranges].each_with_index do |range, i|
          next  unless range.include?(final_score)
          return @scoring[:groups][i], final_score
        end
        nil
      end
  end
end
