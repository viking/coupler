module Coupler
  class Runner 
    class << self
      def run(options)
        spec = YAML.load_file(options.filenames[0])
        runner = self.new(spec, options)
        runner.run_scenarios
      end

      def transform(options)
        spec = YAML.load_file(options.filenames[0])
        runner = self.new(spec, options)
        runner.transform
      end
    end

    def initialize(spec, options)
      @options = options
      @scratch = @scores = nil
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
        @transformers = spec['transformers'].collect do |config|
          Coupler::Transformer.new(config)
        end
      else
        @transformers = []
      end
      @scenarios = spec['scenarios'].collect { |config| Coupler::Scenario.new(config, @options) }
    end

    def run_scenarios
      @scenarios.each do |scenario|
        scenario.run
      end
    end

    def transform
      setup_scratch_database  unless @options.use_existing_scratch
      @scenarios.each do |scenario|
        scenario.transform
      end
    end

    def setup_scratch_database
      schemas = Hash.new { |h, k| h[k] = {:fields => [], :indices => [], :resource => nil} }
      @scenarios.each do |scenario|
        resource = scenario.resource
        schema   = scenario.scratch_schema
        name     = resource.name
        schemas[name][:resource] ||= resource
        schemas[name][:fields]    |= schema[:fields]
        schemas[name][:indices]   |= schema[:indices]
      end

      schemas.each_pair do |name, schema|
        @scratch.drop_table(name)
        @scratch.create_table(name, schema[:fields], schema[:indices])

        # insert ids
        field = schema[:fields].first.split.first   # id int; ugly :/
        res   = schema[:resource].select_with_refill(:columns => [field])
        
        total = schema[:resource].count.to_i
        ids   = Array.new([total, @options.db_limit].min)
        while total > 0
          len = [total, @options.db_limit].min
          len.times { |i| ids[i] = res.next }
          @scratch.insert([field], *ids)
          total -= len
          ids.clear
        end
        res.close
      end
    end
  end
end
