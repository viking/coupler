class Hash
  # Similar to update, except it uses push on values that are already existant
  def push(other)
    other.keys.each do |key|
      if self.has_key?(key)
        self[key].push(*other[key])
      else
        self[key] = other[key]
      end
    end
  end
end
