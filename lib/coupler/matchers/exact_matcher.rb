module Coupler
  module Matchers
    class ExactMatcher
      attr_reader :field, :true_score, :false_score

      def initialize(spec, options)
        @options     = options
        @field       = spec['field']
        @resource    = spec['resource']
        @false_score = spec['scores'] ? spec['scores'].first : 0
        @true_score  = spec['scores'] ? spec['scores'].last  : 100
        @limit       = options.db_limit
      end

      def score(scores)
        key = @resource.primary_key

        # calculate scores
        last    = nil 
        group   = []
        offset  = 0
        records = @resource.select({
          :columns => [key, @field], :order => @field, :limit => @limit
        })
        while (true)
          row = records.next
          if row.nil?
            records.close
            offset += @limit
            records = @resource.select({
              :columns => [key, @field], :order => @field,
              :limit => @limit, :offset => offset
            })
            row = records.next
            break if row.nil?
          end
          id, value = row
          if value == last && !value.nil?
            group.each do |gid|
              scores.add(id, gid, @true_score)
            end
            group << id
          else
            group.clear
            group << id
            last = value
          end
        end
        records.close
      end
    end
  end
end
