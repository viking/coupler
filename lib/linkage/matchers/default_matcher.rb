module Linkage
  module Matchers
    class DefaultMatcher
      attr_reader :field
      def initialize(options)
        @field = options['field']
        @formula = options['formula']
        self.instance_eval(<<-EOF, __FILE__, __LINE__)
          def score(a, bs)
            retval = bs.collect do |b|
              #{@formula}
            end
            retval
          end
        EOF
      end
    end
  end
end
