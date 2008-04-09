class Progress
  RESET = "\r\e[0K"
  STEPS = 50

  def initialize(total)
    @total = total.to_f
    @count = 0
  end

  def next
    return  if done?
    @count += 1
    draw
  end

  def done?
    @count == @total
  end

  def reset!
    @count = 0
  end

  private
    def draw
      percent = @count.to_f / @total
      print "%s[%s>%s] %3.2f%" % [
        RESET, 
        "=" * (percent * STEPS).round, 
        "_" * ((1 - percent) * STEPS).round,
        percent * 100
      ]
      $stdout.flush
      puts  if done?
    end
end
