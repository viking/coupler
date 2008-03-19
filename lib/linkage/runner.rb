module Linkage
  class Runner 
    def self.run(filename)
      spec = YAML.load_file(filename)
      runner = self.new(spec)
    end

    attr_reader :resources
    def initialize(spec)
      @resources = spec['resources'].collect { |config| Linkage::Resource.new(config) }
    end
  end
end
