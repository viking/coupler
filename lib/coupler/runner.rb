module Coupler
  class Runner 
    attr_reader :options, :specification
    def initialize(options = nil)
      @options = options || Options.parse(ARGV)
      @specification = @options.specification || Specification.parse(@options.filename)

      # raise hell if there is no scratch or scores resource
      scratch_templ = @specification['resources'].detect { |r| r['name'] == 'scratch' }
      raise "you must provide a scratch resource!"  unless scratch_templ 
      raise "you must provide a scores resource!"   unless @specification['resources'].detect { |r| r['name'] == 'scores' }

      @transformations = Hash.new { |h, k| h[k] = {:renaming => {}, :transforming => {}} }
      @transformers    = {}
      @resources       = {}
      @scratches       = {}

      @specification['resources'].each do |config|
        name = config['name']
        next  if name == 'scratch'

        @resources[name] = Resource.new(config, @options)
        unless %w{scratch scores}.include?(name)
          # make a scratch resource to parallel this one
          sconfig = scratch_templ.merge({
            'name'  => "#{name}_scratch",
            'table' => config['table'].merge('name' => name)
          })
          @scratches[name] = Resource.new(sconfig, @options)
        end
      end

      if @specification['transformations']
        @specification['transformations']['functions'].each do |config|
          @transformers[config['name']] = Transformer.new(config)
        end
        @specification['transformations']['resources'].each do |resource, config|
          config.each do |info|
            field, tname, rename = info.values_at('field', 'function', 'rename from')
            if rename
              @transformations[resource][:renaming][field] = rename
            else
              @transformations[resource][:transforming][field] = {
                :arguments   => info['arguments'],
                :transformer => tname ? @transformers[tname] : nil,
              }
            end
          end
        end
      end
      @scenarios = @specification['scenarios'].collect { |config| Scenario.new(config, @options) }
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
        h[k] = {
          :fields => [], :indices => [], :info => {},
          :resource => nil, :scratch => nil
        }
      end
      @scenarios.each do |scenario|
        scenario.resources.each do |resource|
          rname  = resource.name
          fields = scenario.field_list
          unless @schemas.has_key?(rname)
            @schemas[rname][:resource] = resource
            @schemas[rname][:scratch]  = @scratches[rname]
            @schemas[rname][:fields]   = [resource.primary_key]
          end
          @schemas[rname][:fields]  |= fields
          @schemas[rname][:indices] |= scenario.indices 
        end
      end

      @schemas.each_pair do |rname, schema|
        # NOTE: resources with no transformations are just 'copied'
        resource = schema[:resource]
        scratch  = schema[:scratch]
        
        # get transformer data types and arguments from the compiled
        # list of fields for each schema
        columns_to_select  = []
        columns_to_inspect = []
        rfields = @transformations[rname][:renaming]
        xfields = @transformations[rname][:transforming]
        schema[:fields].each do |field|
          if (xfield = xfields[field])
            # transforming
            columns_to_select |= xfield[:arguments].values
            schema[:info][field] = xfield[:transformer].data_type
          else
            # renaming or copying
            field = rfields[field]  if rfields.has_key?(field)  # renamed
            columns_to_select  |= [field]
            columns_to_inspect |= [field]
          end
        end

        # get info about fields that we don't know yet
        info = schema[:resource].columns(columns_to_inspect)
        rfields.each_pair { |field, rfield| schema[:info][field] = info[rfield] }
        schema[:fields].each do |field|
          next  if schema[:info][field]
          schema[:info][field] = info[field]
        end

        # setup scratch database
        columns = schema[:fields].collect { |f| "#{f} #{schema[:info][f]}" }
        scratch.drop_table(rname)
        scratch.create_table(rname, columns, schema[:indices])

        # refrigeron, disassemble!
        column_indices = columns_to_select.inject_with_index({}) {|h,(c,i)| h[c]=i; h}
        record_set     = resource.select(:columns => columns_to_select, :order => resource.primary_key, :auto_refill => true)
        insert_buffer  = scratch.insert_buffer(schema[:fields])

        while (record = record_set.next)
          # transform each record
          xrecord = schema[:fields].collect do |field|
            if (xfield = xfields[field])
              # transforming
              arguments, transformer = xfield.values_at(:arguments, :transformer)

              # construct arguments and run transformation
              args = arguments.inject({}) do |hsh, (key, val)|
                hsh[key] = record[column_indices[val]]; hsh
              end
              transformer.transform(args)
            else
              # renaming and copying
              field = rfields[field]  if rfields.has_key?(field)  # renaming
              record[column_indices[field]]
            end
          end
          insert_buffer << xrecord
        end
        insert_buffer.flush!
      end
    end
  end
end
