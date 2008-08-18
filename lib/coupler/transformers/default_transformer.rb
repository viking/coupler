module Coupler
  module Transformers
    class DefaultTransformer
      attr_reader :name, :formula, :parameters, :default, :data_type

      def initialize(options)
        @name       = options['name']
        @formula    = options['formula']
        @default    = options['default']
        @data_type  = options['type']
        @parameters = []

        Transformers.add(@name, self)

        @formula_template = @formula.dup
        @default_template = @default ? @default.dup : "nil"
        options['parameters'].each_with_index do |param, i|
          @parameters << (last = Parameter.new(param.is_a?(Hash) ? param : {'name' => param.to_s}))
          @formula_template.gsub!(/\b#{last.name}\b/, "values[#{i}]")
          @default_template.gsub!(/\b#{last.name}\b/, "values[#{i}]")   if @default
        end if options['parameters'].is_a?(Array)

        self.instance_eval(<<-EOF, __FILE__, __LINE__)
          def run_formula(values)
            #{@formula_template}
          end

          def run_default(values)
            #{@default_template}
          end
        EOF
      end

      def valid?(*values)
        values.each_with_index do |value, i|
          return false  unless @parameters[i].valid?(value)
        end
        true
      end

      def transform(hsh)
        if hsh.is_a?(Hash)
          values = @parameters.collect { |p| hsh[p.name] }
        else
          raise TypeError, "expected Hash"
        end

        if valid?(*values)
          tmp = values
          values = []
          tmp.each_with_index do |value, i|
            values << @parameters[i].convert(value)
          end
          run_formula(values)
        else
          run_default(values)
        end
      end
    end
  end
end
