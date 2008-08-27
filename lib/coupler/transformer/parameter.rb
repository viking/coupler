module Coupler
  module Transformer
    class Parameter
      attr_reader :name, :coerce_to, :regexp, :data_type

      def initialize(options)
        @name      = options['name']
        @coerce_to = options['coerce_to']
        @regexp    = options['regexp'] ? Regexp.new(options['regexp']) : nil
      end

      def valid?(value)
        if @regexp
          value.to_s =~ @regexp ? true : false
        else
          true
        end
      end

      def convert(value)
        return nil  if value.nil?

        case @coerce_to
        when 'integer'
          value.to_i
        when 'string'
          value.to_s
        else
          value
        end
      end
    end
  end
end
