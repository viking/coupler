module Coupler
  module Transformer
    class Downcaser < Base
      @parameters    = %w{from}
      @sql_template  = "LOWER(from)"
      @ruby_template = "from.downcase"
      @type_template = "same as from"
    end
  end
end
