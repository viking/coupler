module Coupler
  module Specification

    class Validator < Kwalify::Validator
      SCHEMA = YAML.load(<<-YAML)
        type: map
        mapping:
          "resources":
            type: seq
            required: yes
            sequence:
              - type: map
                name: resource
                required: yes
                mapping:
                  "name": { type: str, required: yes, unique: yes }
                  "connection":
                    type: map
                    required: yes
                    mapping:
                      "adapter": { type: str, required: yes, enum: [mysql, sqlite3] }
                      "database": { type: str, required: yes }
                      "username": { type: str }
                      "password": { type: str }
                      "host": { type: str }
                  "table":
                    type: map
                    name: table
                    mapping:
                      "name": { type: str }
                      "primary key": { type: str }
          "transformations":
            type: map
            mapping:
              "functions":
                type: seq
                sequence:
                  - type: map
                    name: function
                    mapping:
                      "name": { type: str, unique: yes }
                      "parameters":
                        type: seq
                        sequence:
                          - type: map
                            name: parameter
                            mapping:
                              "name":   { type: str }
                              "regexp": { type: str }
                              "coerce_to": 
                                type: str
                                enum: [integer, string]
                      "formula": { type: str }
                      "default": { type: str }
                      "type": { type: str }
              "resources":
                type: map
                name: namespaced by resource
                mapping:
                  =:
                    type: seq
                    sequence:
                      - type: map
                        name: resource transformation
                        mapping:
                          "field": { type: str }
                          "rename from": { type: str }
                          "function": 
                            type: str
                            name: namespaced by function
                          "arguments":
                            type: map
                            mapping:
                              =: { type: str }
          "scenarios":
            type: seq
            sequence:
            - type: map
              name: scenario
              mapping:
                "name": { type: str, required: yes, unique: yes }
                "type": { type: str, required: yes, enum: [self-join, dual-join] }
                "resource":
                  type: str
                  name: namespaced by resource
                "resources":
                  type: seq
                  sequence: 
                    - type: str
                      name: namespaced by resource
                "matchers":
                  type: seq
                  required: yes
                  sequence:
                    - type: map
                      name: matcher
                      mapping:
                        "field": { type: str }
                        "fields":
                          type: seq
                          sequence: [ { type: str } ]
                        "type":
                          type: str
                          required: yes
                          enum: [exact, default]
                        "formula": { type: str }
                "scoring":
                  type: map
                  required: yes
                  mapping:
                    "combining method":
                      type: str
                      required: yes
                      enum: [sum, mean]
                    "range":
                      type: str
                      required: yes
                      pattern: "/^\\d+\\.{2,3}\\d+$/"
      YAML

      alias :original_validate :validate
      attr_reader :warnings

      def initialize
        super(SCHEMA)
      end

      # NOTE: this isn't stateless anymore; I need to do some namespacing
      def validate(*args)
        @namespaces = {
          'resource' => [], 'function' => [],
          'parameters' => {}
        } 
        @warnings = []
        original_validate(*args)
      end
      
      def validate_hook(value, rule, path, errors)
        return  unless value

        # namespacing
        if %w{resource function}.include?(rule.name)
          @namespaces[rule.name] << value['name']
        end

        # custom validation
        msgs  = case rule.name
                when 'table'
                  _require_map_keys(value, %w{name primary\ key})
                when 'function'
                  _validate_function(value)
                when 'parameter'
                  _require_map_keys(value, %w{name})
                when 'resource transformation'
                  _validate_resource_transformation(value, path)
                when 'scenario'
                  _validate_scenario(value)
                when 'matcher'
                  _validate_matcher(value, path)
                when 'namespaced by resource'
                  names = value.is_a?(Hash)? value.keys : [value]
                  _require_valid_names(names, "resource")
                when /^namespaced by (.+)$/
                  _require_valid_names(value, $1)
                end
        _add_errors(errors, msgs, path) if msgs
      end

      private
        def _require_valid_names(names, category)
          errors = []
          names.each do |name|
            if !@namespaces[category].include?(name)
              errors << "key '#{name}' is not a valid #{category} name."
            end
          end
          errors
        end

        def _require_map_keys(map, keys)
          errors = []
          keys.each do |key|
            errors << Kwalify.msg(:required_nokey) % key  if map[key].nil?
          end
          errors
        end

        def _validate_function(function)
          msgs = _require_map_keys(function, %w{name formula type parameters})
          if (params = function['parameters']) && params.is_a?(Array)
            # save key names for later validation
            keys = params.collect { |p| p['name'] }
            @namespaces['parameters'][function['name']] = keys 

            if params.any? { |p| p['regexp'] } && function['default'].nil?
              msgs << "key 'default' is required when there are one or more parameter restrictions."
            end
          end
          msgs
        end

        def _validate_resource_transformation(transformation, path)
          if transformation['rename from']
            msgs = _require_map_keys(transformation, %w{field})
            %w{function arguments}.each do |key|
              if transformation[key]
                _add_warning("key '#{key}' is ignored when using 'rename from'.", path)
              end
            end
          else
            msgs = _require_map_keys(transformation, %w{field function arguments})
            fname, args = transformation.values_at('function', 'arguments')
            if args && fname
              pkeys = @namespaces['parameters'][fname]
              akeys = args.keys
              if pkeys
                bad     = akeys - pkeys
                missing = pkeys - akeys
                bad.each do |key|
                  msgs << "argument '#{key}' is not valid for the '#{fname}' function."
                end
                missing.each do |key|
                  msgs << Kwalify.msg(:required_nokey) % key
                end
              end
            end
          end
          msgs
        end

        def _validate_scenario(scenario)
          case scenario['type']
          when 'self-join'
            msgs = _require_map_keys(scenario, %w{resource})
          when 'dual-join'
            msgs = _require_map_keys(scenario, %w{resources})
            if (r = scenario['resources']).is_a?(Array) && r.length != 2
              msgs << "two resources are required for dual-join mode."
            end
          end
          msgs
        end

        def _validate_matcher(matcher, path)
          msgs = []
          keys = %w{field fields} - matcher.keys
          case keys.length
          when 2
            msgs << "either 'field' or 'fields' is required."
          when 0
            msgs << "cannot have both 'field' and 'fields'."
          end

          case matcher['type']
          when 'default'
            unless matcher['formula']
              msgs << "key 'formula' is required when type is 'default'."
            end
          when 'exact'
            if matcher['formula']
              _add_warning("key 'formula' is ignored when type is 'exact'.", path)
            end
          end
          msgs
        end

        def _add_errors(errors, msgs, path)
          msgs.each do |msg|
            errors << Kwalify::ValidationError.new(msg, path)
          end
        end

        def _add_warning(msg, path)
          @warnings << Kwalify::ValidationWarning.new(msg, path)
        end
    end

    class << self
      def parse_file(filename)
        if filename =~ /\.erb$/
          parse(Erubis::Eruby.new(File.read(filename)).result(binding))
        else
          parse(File.read(filename))
        end
      end

      def parse(string)
        @validator ||= Validator.new
        obj = YAML.load(string)
        obj.extend(self)
        obj.errors = @validator.validate(obj)
        obj.warnings = @validator.warnings
        obj
      end
    end

    attr_writer :errors, :warnings
    def errors
      @errors ||= []
    end

    def warnings
      @warnings ||= []
    end

    def valid?
      errors.empty?
    end
  end
end

module Kwalify
  class ValidationWarning < BaseError
  end
end
