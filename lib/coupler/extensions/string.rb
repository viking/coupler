class String
  # silly and misleading name 
  def dequotify!
    class << self
      alias :original_inspect :inspect
      alias :inspect :to_s
    end
  end
end
