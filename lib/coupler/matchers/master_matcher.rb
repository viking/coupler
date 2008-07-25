module Coupler
  module Matchers
    class MasterMatcher
      attr_reader :field_list, 
                  :matchers,
                  :combining_method,
                  :range,
                  :resources,
                  :name

      def initialize(spec, options)
        @options = options
        @combining_method = spec['combining method']
        @field_list = spec['field list']   # NOTE: primary key should be first
        @range      = spec['range']
        @scratch    = spec['scratch']
        @scores_db  = spec['scores']
        @parent     = spec['parent']
        @name       = @parent.name
        @resources  = @parent.resources
        @matchers   = []
        @indices    = []
        @defaults   = []
        @caches     = @resources.collect do |resource|
          Cache.new(resource.name, @options)
        end
      end

      def add_matcher(matcher)
        case matcher['type']
        when 'exact'
          matcher['resources'] = @resources
          matcher['scratch']   = @scratch
          @matchers << ExactMatcher.new(matcher, @options)
          @defaults << @matchers.last.false_score
        else
          matcher['index'] = @field_list.index(matcher['field'])
          matcher['cache'] = @cache
          @matchers << DefaultMatcher.new(matcher, @options)
          @defaults << 0
        end
      end

      def score
        scores = Coupler::Scores.new({
          'combining method' => @combining_method,
          'range'    => @range,
          'keys'     => @scratch.keys,
          'num'      => @matchers.length,
          'defaults' => @defaults,
          'resource' => @scores_db,
          'name'     => @name
        }, @options)

        @matchers.each do |matcher|
#          Coupler.logger.info("Scenario (#{name}): Matching on #{matcher.field}")  if Coupler.logger
          scores.record { |r| matcher.score(r) }
        end

        scores
      end
    end
  end
end
