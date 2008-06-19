module Coupler
  class Runner 
    def self.run(options)
      spec = YAML.load_file(options.filenames[0])
      runner = self.new(spec, options)
      runner.run_scenarios
    end

    def initialize(spec, options)
      @options = options
      scratch = scores = false
      @resources = spec['resources'].collect do |config|
        scratch = true  if config['name'] == 'scratch'
        scores  = true  if config['name'] == 'scores'
        Coupler::Resource.new(config)
      end
      # raise hell if there is no scratch or scores resource
      raise "you must provide a scratch resource!"  unless scratch 
      raise "you must provide a scores resource!"   unless scores

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
  end
end
