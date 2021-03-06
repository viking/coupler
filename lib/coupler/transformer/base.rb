module Coupler
  module Transformer
    class Base
      class << self
        attr_accessor :sql_template, :ruby_template,
                      :type_template, :parameters
      end

      attr_reader :field, :arguments
      attr_writer :field_list

      def initialize(options)
        @field      = options['field']
        @arguments  = options['arguments']
        @sql = {}
      end

      def has_sql?
        !!self.class.sql_template
      end

      def sql(adapter = 'default')
        unless @sql[adapter]
          tmpl = self.class.sql_template
          if tmpl.is_a?(Hash)
            tmpl = tmpl.has_key?(adapter) ? tmpl[adapter] : tmpl['default']
          end
          return nil  if tmpl.nil?

          result = sub_argument_names("(#{tmpl})")
          result << " AS #{@field}"
          @sql[adapter] = result
        end
        @sql[adapter]
      end

      def sql_type
        unless @sql_type
          tmpl = self.class.type_template
          @sql_type = case tmpl
                      when /same as (.+)/
                        param = $1
                        tmpl.sub(param, @arguments[param])
                      else
                        tmpl
                      end
        end
        @sql_type
      end

      def transform(row)
        # redefine during the first call
        raise "assign field_list first"   unless @field_list

        formula = self.class.ruby_template.dup
        self.class.parameters.each do |param|
          arg   = @arguments[param]
          index = @field_list.index(arg)
          formula.gsub!(/\b#{param}\b/, "row[#{index}]")
        end

        instance_eval(<<-EOF, __FILE__, __LINE__)
          def transform(row)
            #{formula}
          end
        EOF

        self.transform(row)
      end

      private
        def sub_argument_names(string)
          self.class.parameters.inject(string) do |str, param|
            str.gsub(/\b#{param}\b/, @arguments[param])
          end
        end
    end
  end
end
