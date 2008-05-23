module Linkage
  module Matchers
    class ExactMatcher
      attr_reader :field, :true_score, :false_score

      def initialize(options)
        @field       = options['field']
        @resource    = options['resource']
        @false_score = options['scores'] ? options['scores'].first : 0
        @true_score  = options['scores'] ? options['scores'].last  : 100
      end

      def score(scores)
        key = @resource.primary_key

        # calculate scores
        last    = nil 
        group   = []
        offset  = 0
        records = @resource.select(:columns => [key, @field], :order => @field, :limit => 1000)
        while (true)
          row = records.next
          if row.nil?
            records.close
            offset += 1000
            records = @resource.select({
              :columns => [key, @field], :order => @field,
              :limit => 1000, :offset => offset
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
