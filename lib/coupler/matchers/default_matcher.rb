module Coupler
  module Matchers
    class DefaultMatcher
      attr_reader :field
      def initialize(spec, options)
        @options = options
        @field   = spec['field']
        @index   = spec['index']
        @formula = spec['formula']
        @cache   = spec['cache']
        self.instance_eval(<<-EOF, __FILE__, __LINE__ + 1)
          def score(scores)
            len  = @cache.count - 1
            keys = @cache.keys
            keys.each_with_index do |key, i|
              break if i == len
              a = @cache.fetch(key)[@index]
              candidates = @cache.fetch(keys[(i+1)..-1])
              candidates.each_with_index do |candidate, j|
                b = candidate[@index]
                scores.add(key, keys[i+j+1], #{@formula})
              end
            end
            scores
          end
        EOF
      end
    end
  end
end
