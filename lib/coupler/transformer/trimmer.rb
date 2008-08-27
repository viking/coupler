module Coupler
  module Transformer
    class Trimmer < Base
      @parameters    = %w{from}
      @sql_template  = "TRIM(from)"
      @ruby_template = "from.strip"
      @type_template = "same as from"
    end
  end
end
