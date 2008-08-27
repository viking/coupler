module Coupler
  class Runner
    attr_reader :options, :specification
    def initialize(options = nil)
      @options = options || Options.parse(ARGV)
      @specification = @options.specification || Specification.parse_file(@options.filename)

      # check specification for errors and warnings
      Specification.validate!(@specification)
      if !@specification.warnings.empty?
        $stderr.puts "Specification warnings:"
        @specification.warnings.each do |w|
          $stderr.puts "  [#{w.path}] #{w.message}"
        end
      end
      if !@specification.errors.empty?
        $stderr.puts "Specification errors:"
        @specification.errors.each do |e|
          $stderr.puts "  [#{e.path}] #{e.message}"
        end
        raise "specification errors found!"
      end

      # raise hell if there is no scratch or scores resource
      scratch_templ = @specification['resources'].detect { |r| r['name'] == 'scratch' }
      raise "you must provide a scratch resource!"  unless scratch_templ
      raise "you must provide a scores resource!"   unless @specification['resources'].detect { |r| r['name'] == 'scores' }

      @transformations = Hash.new { |h, k| h[k] = {} }
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

      @scenarios = @specification['scenarios'].collect do |config|
        Scenario.new(config, @options)
      end
    end

    def run
      @scenarios.each do |scenario|
        scenario.run
      end
    end

    def transform
      # build custom transformers
      if @specification['transformations']
        @specification['transformations']['functions'].each do |config|
          Transformer.build(config)
        end
      end

      # set up schemas
      @schemas = Hash.new do |h, k|
        h[k] = {
          :fields => [], :indices => [], :info => {},
          :resource => nil, :scratch => nil, :xfs => {}
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

      # create transformer instances
      @specification['transformations']['resources'].each do |resource, config|
        schema = @schemas[resource]
        config.each do |info|
          field, tname = info.values_at('field', 'function')
          klass = Transformer[tname]
          schema[:xfs][field] = klass.new(info)
        end
      end

      @schemas.each_pair do |rname, schema|
        # NOTE: resources with no transformations are just 'copied'
        resource = schema[:resource]
        scratch  = schema[:scratch]
        xfs = schema[:xfs]

        # get transformer data types and arguments from the compiled
        # list of fields for each schema
        columns_to_select  = []
        columns_to_inspect = {}
        rxfs = []

        schema[:fields].each_with_index do |field, findex|
          if (xf = xfs[field])
            # transforming
            if xf.has_sql?
              columns_to_select |= [xf.sql]
            else
              # needs to be handled in ruby instead of sql
              columns_to_select |= xf.arguments.values
              xf.field_list = schema[:fields]
              rxfs << [findex, xf]
            end

            if xf.sql_type =~ /same as (\w+)/
              columns_to_inspect[field] = $1
            else
              schema[:info][field] = xf.sql_type
            end
          else
            # copying
            columns_to_select |= [field]
            columns_to_inspect[field] = field
          end
        end

        # get info about fields that we don't know yet
        info = schema[:resource].columns(columns_to_inspect.values)
        schema[:fields].each do |field|
          next  if schema[:info][field]
          schema[:info][field] = info[columns_to_inspect[field]]
        end

        # setup scratch database
        columns = schema[:fields].collect { |f| "#{f} #{schema[:info][f]}" }
        scratch.drop_table(rname)
        scratch.create_table(rname, columns, schema[:indices])

        # refrigeron, disassemble!
        record_set    = resource.select(:columns => columns_to_select, :order => resource.primary_key, :auto_refill => true)
        insert_buffer = scratch.insert_buffer(schema[:fields])

        while (record = record_set.next)
          # transform only the necessary columns
          rxfs.each do |index, xf|
            record[index] = xf.transform(record)
          end
          insert_buffer << record
        end
        insert_buffer.flush!
      end
    end
  end
end
