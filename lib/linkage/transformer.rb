module Linkage
  class Transformer
    class Parameter
      attr_reader :name, :coerce_to, :regexp

      def initialize(options)
        options = HashWithIndifferentAccess.new(options)
        @name      = options[:name]
        @coerce_to = options[:coerce_to]

        if options[:conditions]
          @regexp = Regexp.new(options[:conditions][:regexp])
        end
      end

      def valid?(value)
        if @regexp
          value.to_s =~ @regexp ? true : false
        else
          true
        end
      end

      def convert(value)
        case @coerce_to
        when 'integer'
          value.to_i
        when 'string'
          value.to_s
        else
          value
        end
      end
    end

    attr_reader :name, :formula, :parameters, :default

    def initialize(options)
      options = HashWithIndifferentAccess.new(options)
      @name       = options[:name]
      @formula    = options[:formula]
      @default    = options[:default]
      @parameters = []

      @formula_template = @formula.dup
      @default_template = @default ? @default.dup : "nil"
      options[:parameters].each_with_index do |param, i|
        @parameters << (last = Parameter.new(param.is_a?(Hash) ? param : {'name' => param.to_s}))
        @formula_template.gsub!(/\b#{last.name}\b/, "values[#{i}]")
        @default_template.gsub!(/\b#{last.name}\b/, "values[#{i}]")   if @default
      end if options[:parameters].is_a?(Array)
    end

    def valid?(*values)
      values.each_with_index do |value, i|
        return false  unless @parameters[i].valid?(value)
      end
      true
    end

    def transform(*values)
      if valid?(*values)
        tmp = values
        values = []
        tmp.each_with_index do |value, i|
          values << @parameters[i].convert(value)
        end
        eval(@formula_template)
      else
        eval(@default_template)
      end
    end
  end
end
