module Coupler
  module Transformers
    @@transformers = []

    def self.create(options)
      name = options['name']
      raise "duplicate name"  if @@transformers.include?(name)

      @@transformers << name
      Default.new(options)
    end

    def self.reset
      @@transformers.clear
    end
  end
end

require 'coupler/transformers/base'
require 'coupler/transformers/default'
require 'coupler/transformers/parameter'
