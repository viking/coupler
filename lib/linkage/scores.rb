module Linkage
  class Scores
    class Recorder
      attr_reader :parent
      def initialize(parent)
        @parent = parent
      end

      def add(first, second, score)
        @parent.send(:add, first, second, score)
      end
    end

    def initialize(options)
      @keys     = options['keys']
      @num      = options['num']   # number of matchers
      @range    = options['range']
      @defaults = options['defaults']
      @resource = options['resource']
      @name     = options['name']
      @combining_method = options['combining method']

      @finalized  = false
      @pass       = 0
      @indices    = @keys.inject_with_index({}) { |hsh, (key, i)| hsh[key] = i; hsh }
      @length     = @keys.length
      @num_scores = @length * (@length - 1) / 2
      @recorder   = Linkage::Scores::Recorder.new(self)
      @defaults_for_passes = @defaults.inject([nil, 0]) { |arr, d| arr << d + arr.last }
      @score_buffer = {}

      # set up resource
      @resource.drop_table(@name)
      @resource.create_table(@name, ["sid int", "id1 int", "id2 int", "score int", "flags int"])
    end

    def each
      raise "not finalized yet!"  unless @finalized
      
      res = @resource.select(:all, :columns => %w{id1 id2 score flags}, :order => "sid")
      finalized_flag = 2 ** (@pass + 1) - 2
      while (record = res.next)
        id1, id2, score, flags = record
        if flags != finalized_flag 
          # this means there are some default scores to fill in
          1.upto(@num) { |i| score += @defaults[i-1]  if flags & (2 ** i) == 0 }
        end

        case @combining_method
        when 'mean'
          score = score / @num
        end

        yield id1, id2, score   if @range.include?(score)
      end
      res.close
    end

    def record
      raise "already finalized"   if @finalized
      @pass += 1
      yield @recorder

      do_score_replacement

      @finalized = true   if @pass == @num
    end

    private
      def add(id1, id2, score)
        begin
          # switch if id2 comes before id1
          index1  = @indices[id1]
          index2  = @indices[id2]
          if index2 < index1
            tmp = index1; index1 = index2; index2 = tmp
            tmp = id1; id1 = id2; id2 = tmp
          end
          
          # calculate sid based on indices:
          #   ( t(t-1)/2 ) - ( (t-x)(t-x-1)/2 ) - ( y-x )
          #   where t = @length; x = index1; y = index2
          n   = @length - index1 
          sid = @num_scores - (n * (n-1) / 2) + (index2 - index1)

          @score_buffer[sid] = [sid, id1, id2, score, 2 ** @pass]
          do_score_replacement  if @score_buffer.length == 10000

        rescue NoMethodError
          raise "bad keys used for adding scores!"
        end
      end

      def do_score_replacement
        # add scores from the buffer
        return if @score_buffer.empty?  # this happens if no scores were added during this pass

        if @pass == 1
          @resource.insert(%w{sid id1 id2 score flags}, *@score_buffer.values)
        else
          # grab existing scores and flags
          res = @resource.select(:all, {
            :columns => %w{sid score flags},
            :conditions => "WHERE sid IN (#{@score_buffer.keys.join(", ")})",
            :order => "sid"
          })
          while (record = res.next)
            sid, score, flags = record
            @score_buffer[sid][3] += score
            @score_buffer[sid][4] |= flags
          end
          @resource.replace(%w{sid id1 id2 score flags}, *@score_buffer.values)
        end
        @score_buffer.clear
      end
  end
end
