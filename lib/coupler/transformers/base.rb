module Coupler
  module Transformers
    class Base
      attr_reader :name
      def initialize(options)
        @name = options['name']
        Transformers.add(@name, self)
      end

      def transform(*args)
        raise NotImplementedError
      end
    end
  end
end
