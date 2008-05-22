module Linkage
  module Matchers
    class ExactMatcher
      attr_reader :field, :true_score, :false_score

      def initialize(options)
        @field       = options['field']
        @index       = options['index']
        @resource    = options['resource']
        @false_score = options['scores'] ? options['scores'].first : 0
        @true_score  = options['scores'] ? options['scores'].last  : 100
      end

      def score
        # grab ids so I know what order the scores should be in
        key = @resource.primary_key
        ids = @resource.select(:columns => [key], :order => key)
        count   = 0
        indices = {}
        while (row = ids.next)
          indices[row.first] = count
          count += 1
        end
        ids.close

        # calculate scores
        len     = count - 1
        scores  = Array.new(len) { |i| Array.new(len-i, @false_score) }
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
          i = indices[id]
          if value == last && !value.nil?
            group.each do |j|
              if j < i 
                scores[j][i-j-1] = @true_score
              else
                scores[i][j-i-1] = @true_score
              end
            end
            group << i
          else
            group.clear
            group << i
            last = value
          end
        end
        records.close

        scores
      end
    end
  end
end
