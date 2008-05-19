module Linkage
  module Matchers
    class DefaultMatcher
      attr_reader :field
      def initialize(options)
        @field   = options['field']
        @index   = options['index']
        @formula = options['formula']
        @cache   = options['cache']
        self.instance_eval(<<-EOF, __FILE__, __LINE__)
          def score
            len    = @cache.count - 1
            scores = Array.new(len) { |i| Array.new(len-i) }

            keys = @cache.keys
            keys.each_with_index do |key, i|
              break if i == len
              a = @cache.fetch(key)[@index]
              candidates = @cache.fetch(keys[(i+1)..-1])
              candidates.each_with_index do |candidate, j|
                b = candidate[@index]
                scores[i][j] = #{@formula}
              end
            end
            scores
          end
        EOF
      end
    end
  end
end
