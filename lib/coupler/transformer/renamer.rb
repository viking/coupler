module Coupler
  module Transformer
    class Renamer < Base
      @parameters    = %w{from}
      @sql_template  = "from"
      @ruby_template = "from"
      @type_template = "same as from"
    end
  end
end
