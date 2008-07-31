module Coupler
  module Matchers
    class MasterMatcher
      attr_reader :field_list, 
                  :matchers,
                  :combining_method,
                  :range,
                  :resources,
                  :name

      def initialize(parent, options)
        @parent    = parent
        @options   = options
        @matchers  = []
        @indices   = []
        @defaults  = []

        @scores_db  = Resource.find('scores')
        @range      = @parent.range
        @field_list = @parent.field_list
        @name       = @parent.name
        @resources  = @parent.scratches
        @combining_method = @parent.combining_method
        @caches = @resources.collect do |resource|
          CachedResource.new(resource.name, @options)
        end
        @filled = false
      end

      def add_matcher(matcher)
        case matcher['type']
        when 'exact'
          matcher['resources'] = @resources
          @matchers << ExactMatcher.new(matcher, @options)
          @defaults << @matchers.last.false_score
        else
          unless @filled
            @caches.each { |cache| cache.auto_fill! }
            @filled = true
          end
          matcher['index']  = @field_list.index(matcher['field'])
          matcher['caches'] = @caches
          @matchers << DefaultMatcher.new(matcher, @options)
          @defaults << 0
        end
      end

      def score
        scores = Coupler::Scores.new({
          'combining method' => @combining_method,
          'range'    => @range,
          'keys'     => @resources.collect { |r| r.keys },
          'num'      => @matchers.length,
          'defaults' => @defaults,
          'resource' => @scores_db,
          'name'     => @name
        }, @options)

        @matchers.each do |matcher|
          Coupler.logger.info("Scenario (#{name}): Matching on #{matcher.field}")  if Coupler.logger
          scores.record { |r| matcher.score(r) }
        end

        scores
      end
    end
  end
end
