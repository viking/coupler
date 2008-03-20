module Linkage
  class Runner 
    def self.run(filename)
      spec = YAML.load_file(filename)
      runner = self.new(spec)
    end

    def initialize(spec)
      @resources    = spec['resources'].collect    { |config| Linkage::Resource.new(config) }
      @transformers = spec['transformers'].collect { |config| Linkage::Transformer.new(config) }
    end
  end
end
