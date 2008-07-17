module Coupler
  class Runner 
    class << self
      def run(*args)
        perform(:run, args)
      end

      def transform(*args)
        perform(:transform, args)
      end

      private
        def perform(action, args)
          options = args.pop
          spec    = args.first
          unless spec
            filename = options.filenames.first
            if filename =~ /\.erb$/
              spec = YAML.load(Erubis::Eruby.new(File.read(filename)).result(binding))
            else
              spec = YAML.load_file(filename)
            end
          end
          runner = self.new(spec, options)
          runner.send(action)
        end
    end

    def initialize(spec, options)
      @options = options
      @scratch = @scores = nil
      @transformers = {}
      @transformations = Hash.new { |h, k| h[k] = {} }
      @resources = spec['resources'].collect do |config|
        r = Coupler::Resource.new(config, @options)
        case config['name']
        when 'scratch'
          @scratch = r
        when 'scores'
          @scores = r
        end
        r
      end
      # raise hell if there is no scratch or scores resource
      raise "you must provide a scratch resource!"  unless @scratch 
      raise "you must provide a scores resource!"   unless @scores

      if spec['transformers']
        spec['transformers']['functions'].each do |config|
          @transformers[config['name']] = Coupler::Transformer.new(config)
        end
        spec['transformers']['resources'].each do |resource, config|
          config.each do |info|
            field, tname = info.values_at('field', 'function')
            @transformations[resource][field] = {
              :arguments   => info['arguments'],
              :transformer => @transformers[tname] 
            }
          end
        end
      end
      @scenarios = spec['scenarios'].collect { |config| Coupler::Scenario.new(config, @options) }
    end

    def run
      @scenarios.each do |scenario|
        scenario.run
      end
    end

    def transform
      return  if @options.use_existing_scratch

      # set up schemas
      @schemas = Hash.new do |h, k|
        h[k] = {:fields => [], :indices => [], :resource => nil, :info => {}}
      end
      @scenarios.each do |scenario|
        resource = scenario.resource
        rname    = resource.name
        fields   = scenario.field_list
        @schemas[rname][:resource] ||= resource
        @schemas[rname][:fields]    |= fields
        @schemas[rname][:indices]   |= scenario.indices 
      end

      @schemas.each_pair do |rname, schema|
        # NOTE: resources with no transformations are just 'copied'
        resource = schema[:resource]
        
        # get transformer data types and arguments from the compiled
        # list of fields for each schema
        columns = []
        xfields = @transformations[rname]
        schema[:fields].each do |field|
          if (xfield = xfields[field]).nil?
            # this field isn't transformed
            columns << field
          else
            columns |= xfield[:arguments].values
            schema[:info][field] = xfield[:transformer].data_type
          end
        end

        # setup scratch database
        setup_scratch_database(rname, schema)

        # refrigeron, disassemble!
        record_set    = resource.select(:columns => columns, :order => resource.primary_key, :auto_refill => true)
        insert_buffer = @scratch.insert_buffer(schema[:fields])

        while (record = record_set.next)
          # transform each record
          xrecord = schema[:fields].collect do |field|
            if (xfield = xfields[field])
              arguments, transformer = xfield.values_at(:arguments, :transformer)

              # construct arguments and run transformation
              args = arguments.inject({}) do |hsh, (key, val)|
                hsh[key] = record[columns.index(val)]; hsh
              end
              transformer.transform(args)
            else
              record[columns.index(field)]
            end
          end
          insert_buffer << xrecord
        end
        insert_buffer.flush!
      end
    end

    def setup_scratch_database(rname, schema)
      @scratch.drop_table(rname)

      # get info about fields that we don't know about yet (non-transformed fields)
      fields_needed = schema[:fields] - schema[:info].keys
      schema[:info].merge!(schema[:resource].columns(fields_needed))

      # create that shiz
      columns = schema[:fields].collect { |f| "#{f} #{schema[:info][f]}" }
      @scratch.create_table(rname, columns, schema[:indices])
    end
  end
end
