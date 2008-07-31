module Coupler
  module Matchers
    class DefaultMatcher
      # FIXME: this is horribly slow.

      attr_reader :field 
      def initialize(spec, options)
        @options = options
        @field   = spec['field']
        @index   = spec['index']
        @formula = spec['formula']
        @caches  = spec['caches']

        if @caches.length == 1
          self.instance_eval(<<-EOF, __FILE__, __LINE__ + 1)
            def score(scores)
              len  = @caches[0].count - 1
              keys = @caches[0].keys
              keys.each_with_index do |key, i|
                break if i == len
                a = @caches[0].fetch(key)[@index]
                candidates = @caches[0].fetch(keys[(i+1)..-1])
                candidates.each_with_index do |candidate, j|
                  b = candidate[@index]
                  scores.add(key, keys[i+j+1], #{@formula})
                end
              end
              scores
            end
          EOF
        else
          self.instance_eval(<<-EOF, __FILE__, __LINE__ + 1)
            def score(scores)
              candidates = @caches[1].fetch(@caches[1].keys)
              @caches[0].keys.each do |key|
                a = @caches[0].fetch(key)[@index]
                candidates.each do |candidate|
                  b = candidate[@index]
                  scores.add(key, candidate[0], #{@formula})
                end
              end
              scores
            end
          EOF
        end
      end
    end
  end
end
