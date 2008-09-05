require 'coupler/transformer/parameter'
require 'coupler/transformer/base'
require 'coupler/transformer/trimmer'
require 'coupler/transformer/renamer'
require 'coupler/transformer/downcaser'
require 'coupler/transformer/custom'

module Coupler
  module Transformer
    @@transformers = {
      "trimmer" => Trimmer,
      "renamer" => Renamer,
      "downcaser" => Downcaser
    }
    def self.[](name)
      @@transformers[name]
    end

    def self.build(options)
      @@transformers[options['name']] = Custom.build(options)
    end
  end
end
