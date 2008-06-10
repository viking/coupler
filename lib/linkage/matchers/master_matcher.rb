module Linkage
  module Matchers
    class MasterMatcher
      attr_reader :field_list, :matchers, :combining_method, :range

      def initialize(options = {})
        @combining_method = options['combining method']
        @field_list = options['field list']   # NOTE: primary key should be first
        @range      = options['range']
        @resource   = options['resource']
        @cache      = options['cache']
        @matchers   = []
        @indices    = []
        @defaults   = []
      end

      def add_matcher(options)
        case options['type']
        when 'exact'
          options['resource'] = @resource
          @matchers << ExactMatcher.new(options)
          @defaults << @matchers.last.false_score
        else
          options['index'] = @field_list.index(options['field'])
          options['cache'] = @cache
          @matchers << DefaultMatcher.new(options)
          @defaults << 0
        end
      end

      def score
        scores = Linkage::Scores.new({
          'combining method' => @combining_method,
          'range' => @range,
          'keys'  => @resource.keys,
          'num'   => @matchers.length,
          'defaults' => @defaults 
        })

        @matchers.each do |matcher|
          scores.record { |r| matcher.score(r) }
        end

        scores
      end
    end
  end
end
