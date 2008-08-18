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
        # chicken/egg problem; sometimes resources is processed after
        # transformations, which means that no resource name is valid
        @valid_names = {
          'resource' => [], 'function' => [],
          'parameters' => {}
        } 
        @candidates = {
          'resource' => [], 'function' => [],
          'parameters' => Hash.new { |h, k| h[k] = [] } 
        }

        @warnings = []
        errors = original_validate(*args)
        _check_names(errors)
        errors
      end
      
      def validate_hook(value, rule, path, errors)
        return  unless value

        # custom validation
        msgs  = case rule.name
                when 'table'
                  _require_map_keys(value, %w{name primary\ key})
                when 'function'
                  _add_valid_name('function', value['name']) # namespacing
                  _validate_function(value)
                when 'resource'
                  _add_valid_name('resource', value['name']) # namespacing
                  nil
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
                  names.each do |name|
                    # namespacing
                    _add_name_candidate(name, path, "resource")
                  end
                  nil
                when /^namespaced by (.+)$/
                  # namespacing
                  _add_name_candidate(value, path, $1)
                  nil
                end
        _add_errors(errors, msgs, path) if msgs
      end

      private
        def _check_names(errors) 
          %w{resource function}.each do |category| 
            names = @valid_names[category]
            @candidates[category].each do |(name, path)|
              if !names.include?(name)
                msg = "key '#{name}' is not a valid #{category} name."
                _add_error(errors, msg, path)
              end
            end
          end

          # check parameters
          @candidates['parameters'].each do |fname, candidates|
            candidates.each do |hsh|
              names  = hsh[:arguments]
              path   = hsh[:path]
              vnames = @valid_names['parameters'][fname]
              if vnames
                bad     = names - vnames
                missing = vnames - names
                bad.each do |key|
                  msg = "argument '#{key}' is not valid for the '#{fname}' function."
                  _add_error(errors, msg, path)
                end
                missing.each do |key|
                  msg = Kwalify.msg(:required_nokey) % key
                  _add_error(errors, msg, path)
                end
              end
            end
          end
        end

        def _add_valid_name(category, name)
          @valid_names[category] << name
        end

        def _add_name_candidate(name, path, category)
          @candidates[category] << [name, path]
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
            @valid_names['parameters'][function['name']] = keys 

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
              @candidates['parameters'][fname] << { 
                :arguments => args.keys, :path => path
              }
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
            _add_error(errors, msg, path)
          end
        end

        def _add_error(errors, msg, path)
          errors << Kwalify::ValidationError.new(msg, path)
        end

        def _add_warning(msg, path)
          @warnings << Kwalify::ValidationWarning.new(msg, path)
        end
    end

    class << self
      def parse_file(filename)
        string = if filename =~ /\.erb$/
          Erubis::Eruby.new(File.read(filename)).result(binding)
        else
          File.read(filename)
        end
        parse(string)
      end

      def parse(string)
        YAML.load(string)
      end

      def validate!(obj)
        @validator ||= Validator.new
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
