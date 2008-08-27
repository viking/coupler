require 'coupler/transformer/parameter'
require 'coupler/transformer/base'
require 'coupler/transformer/trimmer'
require 'coupler/transformer/renamer'
require 'coupler/transformer/custom'

module Coupler
  module Transformer
    @@transformers = {
      "trimmer" => Trimmer,
    }
    def self.[](name)
      @@transformers[name]
    end

    def self.build(options)
      @@transformers[options['name']] = Custom.build(options)
    end
  end
end
