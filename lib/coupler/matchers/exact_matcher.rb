module Coupler
  module Matchers
    class ExactMatcher
      attr_reader :fields, :true_score, :false_score

      def initialize(spec, options)
        @options     = options
        @fields      = spec['field'] ? [spec['field']] : spec['fields']
        @resources   = spec['resources']
        @false_score = spec['scores'] ? spec['scores'].first : 0
        @true_score  = spec['scores'] ? spec['scores'].last  : 100
      end

      def score(scores)
        order = @fields.join(", ")
        conditions = "WHERE #{@fields.collect { |f| "#{f} IS NOT NULL" }.join(" AND ")}"
        last = nil 
        group = []

        if @resources.length == 1
          key = @resources[0].primary_key
          columns = [key] + @fields
          order << ", #{key}" 
          set = @resources[0].select({
            :columns => columns, :order => order, 
            :auto_refill => true, :conditions => conditions 
          })
          while (row = set.next)
            id = row.shift
            if row == last
              group.each do |gid|
                scores.add(gid, id, @true_score)
              end
              group << id
            else
              group.clear
              group << id
              last = row
            end
          end
        else
          sets = @resources.collect do |resource|
            key = resource.primary_key
            resource.select({
              :columns => [key] + @fields, :order => order + ", #{key}",
              :auto_refill => true, :conditions => conditions 
            })
          end
          
          # FIXME: it might be better if I had Resource#join or something,
          #        but I'm feeling lazy right now.
          # NOTE:  this algorithm assumes that the SQL comparisons
          #        do the same thing as Ruby's, which might be a 
          #        bad assumption
          last  = sets[0].next
          group = [last.shift]
          row2  = sets[1].next
          id2   = row2.shift
          loop do 
            row1 = sets[0].next
            id1  = row1.shift   if row1
            if row1 == last
              group << id1
            else
              loop do
                case row2 <=> last
                when 0
                  group.each do |gid|
                    scores.add(gid, id2, @true_score)
                  end
                when 1
                  break
                end

                row2 = sets[1].next
                break if row2.nil?
                id2 = row2.shift
              end
              break if row1.nil? || row2.nil?

              group.clear
              group << id1
              last = row1
            end
          end
        end
      end
    end
  end
end
