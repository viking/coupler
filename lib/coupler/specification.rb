module Coupler
  class Specification
    attr_reader :resources, :transformations, :scenarios
    def initialize(filename)
      raw = if filename =~ /\.erb$/
            then YAML.load(Erubis::Eruby.new(File.read(filename)).result(binding))
            else YAML.load_file(filename)
            end

      @resources = raw['resources']
      @scenarios = raw['scenarios']
      @transformations = raw['transformations']
    end
  end
end
