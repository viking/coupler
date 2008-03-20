module Linkage
  class Scenario
    class Matcher
      attr_reader :field
      def initialize(options)
        @field = options['field']
        @formula = options['formula']
      end

      def score(a, b)
        eval(@formula)
      end
    end

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

      @transformations = []
      options[:transformations].each do |info|
        t = Linkage::Transformer.find(info['transformer'])
        raise "can't find transformer '#{info['transformer']}'"  unless t
        info['transformer'] = t
        @transformations << info
      end if options[:transformations]

      @matchers = options[:matchers].collect { |config| Matcher.new(config) }
    end

    def run
      retval = {}

      case @type
      when 'self-join'
        klass = @resources[0].record
        primary_key = klass.primary_key

        # find all records
        records = klass.find(:all).collect { |r| do_transformation(r.attributes) }
        records.each_with_index do |record, i|
          # run matchers
          result = {}
          records[(i+1)..(records.length)].each do |candidate|
            result[candidate[primary_key]] = @matchers.collect do |matcher| 
              field = matcher.field
              matcher.score(record[field], candidate[field])
            end
          end

          retval[record[primary_key]] = result  unless result.empty?
        end
      end

      # return score hash
      retval
    end

    private
      def do_transformation(record)
        @transformations.each do |info|
          transformer = info['transformer']
          field = info['name']
          args = info['arguments'].inject({}) do |args, (key, val)|
            args[key] = record[val]
          args
          end
          record[field] = transformer.transform(args)
        end
        record
      end
  end
end
