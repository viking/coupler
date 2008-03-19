module Linkage
  class Resource
    attr_reader :name, :table, :abstract_base, :records

    def initialize(options = {})
      options = HashWithIndifferentAccess.new(options)
      @name  = options[:name]
      ActiveRecord::Base.configurations[@name] = options[:connection]

      # create an abstract base class
      @abstract_base = self.class.subclass("AbstractBase", ActiveRecord::Base) do
        self.abstract_class = true
      end
      @abstract_base.establish_connection(@name)

      @records = options[:tables].inject(HashWithIndifferentAccess.new) do |hsh, table_name|
        hsh[table_name] = klass = @abstract_base.subclass("Table")
        klass.set_table_name(table_name)
        hsh
      end
    end
  end
end
