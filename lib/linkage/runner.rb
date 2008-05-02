module Linkage
  class Runner 
    def self.run(filename)
      spec = YAML.load_file(filename)
      runner = self.new(spec)
      runner.run_scenarios
    end

    def initialize(spec)
      scratch = false
      @resources = spec['resources'].collect do |config|
        scratch = true  if config['name'] == 'scratch'
        Linkage::Resource.new(config)
      end
      # raise hell if there is no scratch database
      raise "you must provide a scratch resource!"  unless scratch 

      if spec['transformers']
        @transformers = spec['transformers'].collect do |config|
          Linkage::Transformer.new(config)
        end
      else
        @transformers = []
      end
      @scenarios = spec['scenarios'].collect    { |config| Linkage::Scenario.new(config) }
    end

    def run_scenarios
      disabled = GC.disable  if ENV['GC_OFF']
      @scenarios.each do |scenario|
        result  = scenario.run
        outfile = File.open("#{scenario.name}.csv", "w")
        csv     = CSV::Writer.create(outfile)
        csv << %w{id1 id2 score group}
        result.each_pair do |group, scores|
          scores.each do |(id1, id2, score)|
            csv << [id1, id2, score, group]
          end
        end
        csv.close
        outfile.close
      end
      GC.enable   unless disabled
    end
  end
end
