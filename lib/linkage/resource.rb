module Linkage
  class Resource
    @@resources = {}

    attr_reader :name, :table, :abstract_base, :record

    def initialize(options = {})
      options = HashWithIndifferentAccess.new(options)
      @name   = options[:name]
      if @@resources.keys.include?(@name)
        raise "duplicate name"
      else
        @@resources[@name] = self
      end
      ActiveRecord::Base.configurations[@name] = options[:connection]

      # create an abstract base class
      @abstract_base = self.class.subclass("AbstractBase", ActiveRecord::Base) do
        self.abstract_class = true
      end
      @abstract_base.establish_connection(@name)

      table = options[:table]
      @record = @abstract_base.subclass("Table")
      @record.set_table_name(table[:name])
      @record.set_primary_key(table[:primary_key])  if table[:primary_key]
    end

    def self.find(name)
      @@resources[name]
    end
  end
end
