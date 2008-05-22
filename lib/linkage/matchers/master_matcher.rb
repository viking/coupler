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
        
        instance_eval(ERB.new(<<-EOF).result(binding), __FILE__, __LINE__)
          def get_group(score)
            case score
          <% @groups.each_pair do |name, range| %>
            when <%= range %> then "<%= name %>"
          <% end %>
            else
              nil
            end
          end
        EOF
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
          Linkage.logger.debug "Running matcher for #{matcher.field}"   if Linkage.logger
          scores[i] = matcher.score
        end

        Linkage.logger.debug "Combining scores"   if Linkage.logger
        retval = Hash.new { |h, k| h[k] = [] }
        ids    = @cache.keys
        len    = ids.length - 1
        len.times do |i|
          Linkage.logger.debug "Scoring: #{i}"   if Linkage.logger && i % 1000 == 0
          (len - i).times do |j|
            score = scores.collect { |s| s[i][j] }.send(@combining_method)
            group = get_group(score) 
            retval[group] << [ids[i], ids[i+j+1], score]  if group
          end
        end
        Linkage.logger.debug "Done combining"   if Linkage.logger
        retval
      end
    end
  end
end
