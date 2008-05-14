class Array
  def extract_options!
    last.is_a?(::Hash) ? pop : {}
  end

  def sum
    self.inject(0) { |sum, n| sum + n }
  end

  def mean
    self.sum / self.length
  end
end
