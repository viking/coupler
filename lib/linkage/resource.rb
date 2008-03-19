module Linkage
  class Resource
    cattr_accessor :names
    self.names = []

    attr_reader :name, :table, :abstract_base, :record

    def initialize(options = {})
      options = HashWithIndifferentAccess.new(options)
      @name   = options[:name]
      if self.class.names.include?(@name)
        raise "duplicate name"
      else
        self.names << @name
      end
      ActiveRecord::Base.configurations[@name] = options[:connection]

      # create an abstract base class
      @abstract_base = self.class.subclass("AbstractBase", ActiveRecord::Base) do
        self.abstract_class = true
      end
      @abstract_base.establish_connection(@name)

      @record = @abstract_base.subclass("Table")
      @record.set_table_name(options[:table])
    end
  end
end
