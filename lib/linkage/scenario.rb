module Linkage
  class Scenario
    attr_reader :name, :type, :resources
    def initialize(options, resources = [])
      options = HashWithIndifferentAccess.new(options)
      @name = options[:name]
      @type = options[:type]
      @resources = resources.is_a?(Array) ? resources : [resources]
    end
  end
end
