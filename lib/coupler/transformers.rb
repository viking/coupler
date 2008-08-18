module Coupler
  module Transformers
    @@transformers = {}

    def self.add(name, obj)
      if @@transformers.keys.include?(name)
        raise "duplicate name"
      else
        @@transformers[name] = obj
      end
    end

    def self.find(name)
      @@transformers[name]
    end

    def self.reset
      @@transformers.clear
    end
  end
end

require 'coupler/transformers/default_transformer'
require 'coupler/transformers/parameter'
