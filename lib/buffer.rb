class Buffer
  include Enumerable

  attr_reader :length
  def initialize(capacity)
    @buffer = Array.new(capacity)
    @capa   = capacity
    @length = 0
  end

  def <<(value)
    raise "buffer is full"  if full?
    @buffer[@length] = value
    @length += 1
    self
  end

  def each(&block)
    data.each(&block)
  end

  def full?
    @length == @capa
  end
  
  def empty?
    @length == 0
  end

  def flush!
    @length = 0
  end

  def data
    @buffer[0, @length]
  end
end
