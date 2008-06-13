module Linkage
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
        Linkage::Resource.new(config)
      end
      # raise hell if there is no scratch or scores resource
      raise "you must provide a scratch resource!"  unless scratch 
      raise "you must provide a scores resource!"   unless scores

      if spec['transformers']
        @transformers = spec['transformers'].collect do |config|
          Linkage::Transformer.new(config)
        end
      else
        @transformers = []
      end
      @scenarios = spec['scenarios'].collect { |config| Linkage::Scenario.new(config, @options) }
    end

    def run_scenarios
      @scenarios.each do |scenario|
        result = scenario.run
        FasterCSV.open("#{scenario.name}.csv", "w") do |csv|
          csv << %w{id1 id2 score}
          result.each do |id1, id2, score|
            csv << [id1, id2, score]
          end
        end
      end
    end
  end
end
