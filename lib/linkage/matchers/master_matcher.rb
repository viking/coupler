module Linkage
  module Matchers
    class MasterMatcher
      attr_reader :field_list, :matchers, :combining_method, :range

      def initialize(spec, options)
        @options = options
        @combining_method = spec['combining method']
        @field_list = spec['field list']   # NOTE: primary key should be first
        @range      = spec['range']
        @resource   = spec['resource']
        @cache      = spec['cache']
        @name       = spec['name']
        @scores_db  = spec['scores']
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
          'range'    => @range,
          'keys'     => @resource.keys,
          'num'      => @matchers.length,
          'defaults' => @defaults,
          'resource' => @scores_db,
          'name'     => @name
        }, @options)

        @matchers.each do |matcher|
          scores.record { |r| matcher.score(r) }
        end

        scores
      end
    end
  end
end
