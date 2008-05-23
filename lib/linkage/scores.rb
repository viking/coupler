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
      @combining_method = options['combining method']

      @finalized = false
      @pass      = 0
      @indices   = {}
      @length    = @keys.length
      @scores    = Array.new(@length - 1) do |i|
        @indices[@keys[i]] = i
        Array.new(@length - 1 - i, @defaults.sum)
      end
      @indices[@keys.last] = @keys.length - 1
      @recorder = Linkage::Scores::Recorder.new(self)
    end

    def [](key, other)
      raise "not finalized yet!"  unless @finalized
      return nil  unless @keys.include?(key)
      i = @indices[key]
      j = @indices[other]

      case @combining_method
      when 'sum'
        @scores[i][j-i-1]
      when 'mean'
        @scores[i][j-i-1] / @num
      end
    end

    def each
      raise "not finalized yet!"  unless @finalized
      len = @length - 1
      len.times do |i|
        (len-i).times do |j|
          score = case @combining_method
                  when "sum"  then @scores[i][j]
                  when "mean" then @scores[i][j] / @num
                  end
          next  unless @range.include?(score)
          yield(@keys[i], @keys[i+j+1], score)
        end
      end
    end

    def record
      raise "already finalized"   if @finalized
      @pass += 1
      yield @recorder
      @finalized = true   if @pass == @num
    end

    private
      def add(first, second, score)
        begin
          default = @defaults[@pass-1]
          i = @indices[first]
          j = @indices[second]
          score -= default
          if i < j 
            @scores[i][j-i-1] += score
          else
            @scores[j][i-j-1] += score
          end
        rescue NoMethodError
          raise "bad keys used for adding scores!"
        end
      end
  end
end
