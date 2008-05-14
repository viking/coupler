module Linkage
  module Matchers
    class MasterMatcher
      attr_reader :field_list, :matchers, :combining_method, :groups

      def initialize(options = {})
        @field_list = options['field list']   # NOTE: primary key should be first
        @combining_method = options['combining method']
        @groups = options['groups']
        @matchers = []
        @indices  = []

        @combine_proc = case @combining_method
          when "mean"
            lambda { |scores| scores.mean }
          when "sum"
            lambda { |scores| scores.sum }
        end
      end

      def add_matcher(options)
        case options['type']
        when 'exact'
          @matchers << ExactMatcher.new(options)
        else
          @matchers << DefaultMatcher.new(options)
        end
        @indices << @field_list.index(@matchers.last.field)
      end

      def score(record, candidates)
        candidates = [candidates] unless candidates[0].is_a?(Array)
        scores = []
        @matchers.each_with_index do |matcher, i|
          index = @indices[i]
          scores << matcher.score(record[index], candidates.collect { |c| c[index] })
        end

        # combine and group scores
        scores.transpose.inject_with_index(Hash.new{|h,k| h[k]=[]}) do |hsh, (scores, i)|
          score = @combine_proc.call(scores)
          group = @groups.keys.detect { |name| @groups[name].include?(score) }
          hsh[group] << [record[0], candidates[i][0], score]  if group
          hsh
        end
      end
    end
  end
end
