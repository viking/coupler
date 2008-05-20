module Linkage
  module Matchers
    class MasterMatcher
      attr_reader :field_list, :matchers, :combining_method, :groups

      def initialize(options = {})
        @combining_method = options['combining method']
        @field_list = options['field list']   # NOTE: primary key should be first
        @groups     = options['groups']
        @resource   = options['resource']
        @cache      = options['cache']
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
        options['index'] = @field_list.index(options['field'])
        case options['type']
        when 'exact'
          options['resource'] = @resource
          @matchers << ExactMatcher.new(options)
        else
          options['cache'] = @cache
          @matchers << DefaultMatcher.new(options)
        end
      end

      def score
        scores = Array.new(@matchers.length)
        @matchers.each_with_index do |matcher, i|
          scores[i] = matcher.score
        end

        retval = Hash.new { |h, k| h[k] = [] }
        ids    = @cache.keys
        len    = ids.length - 1
        len.times do |i|
          (len - i).times do |j|
            score = @combine_proc.call(scores.collect { |s| s[i][j] })
            group = @groups.keys.detect { |name| @groups[name].include?(score) }
            retval[group] << [ids[i], ids[i+j+1], score]  if group
          end
        end
        retval
      end
    end
  end
end
