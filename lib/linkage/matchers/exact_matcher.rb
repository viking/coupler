module Linkage
  module Matchers
    class ExactMatcher
      attr_reader :field, :true_score, :false_score

      def initialize(options)
        @field = options['field']
        @false_score = options['scores'] ? options['scores'].first : 0
        @true_score  = options['scores'] ? options['scores'].last  : 100
      end

      def score(record, candidates)
        retval = candidates.collect do |candidate|
          record == candidate ? @true_score : @false_score 
        end
        retval
      end
    end
  end
end
