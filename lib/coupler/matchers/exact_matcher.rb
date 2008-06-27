module Coupler
  module Matchers
    class ExactMatcher
      attr_reader :fields, :true_score, :false_score

      def initialize(spec, options)
        @options     = options
        @fields      = spec['field'] ? [spec['field']] : spec['fields']
        @resource    = spec['resource']
        @false_score = spec['scores'] ? spec['scores'].first : 0
        @true_score  = spec['scores'] ? spec['scores'].last  : 100
        @limit       = options.db_limit
      end

      def score(scores)
        key = @resource.primary_key

        # calculate scores
        last   = nil 
        group  = []
        offset = 0
        order  = @fields.join(", ")
        columns = [key] + @fields
        conditions = "WHERE #{@fields.collect { |f| "#{f} IS NOT NULL" }.join(" AND ")}"
        records = @resource.select({
          :columns => columns, :order => order, 
          :limit => @limit, :conditions => conditions 
        })
        while (true)
          row = records.next
          if row.nil?
            records.close
            offset += @limit
            records = @resource.select({
              :columns => columns, :order => order, :offset => offset,
              :limit => @limit, :conditions => conditions
            })
            row = records.next
            break if row.nil?
          end

          id = row.shift
          if row == last
            group.each do |gid|
              scores.add(id, gid, @true_score)
            end
            group << id
          else
            group.clear
            group << id
            last = row
          end
        end
        records.close
      end
    end
  end
end
