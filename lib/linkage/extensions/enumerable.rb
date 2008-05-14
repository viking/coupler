module Enumerable
  def inject_with_index(*args, &block)
    enum_for(:each_with_index).inject(*args, &block)
  end
end
