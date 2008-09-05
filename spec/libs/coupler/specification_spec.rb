require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Specification do
  before(:each) do
    @filename = File.dirname(__FILE__) + "/../../fixtures/sauce.yml"
    @raw_spec = YAML.load_file(@filename)
  end

  def parse_file
    Coupler::Specification.parse_file(@filename)
  end

  def parse_string(string)
    Coupler::Specification.parse(string)
  end

  def validate(obj)
    Coupler::Specification.validate!(obj)
  end

  it "should load the file and return a hash" do
    parse_file.should == @raw_spec
  end

  it "should load a string" do
    parse_string(File.read(@filename)).should == @raw_spec
  end

  it "should pass a templated file through Erubis first" do
    @filename << ".erb"
    parse_file.should == @raw_spec
  end

  describe "#valid?" do
    before(:each) do
      @spec = YAML.load(<<-EOF)
        resources:
          - name: foo
            connection:
              adapter: mysql
              database: pants
              username: foo
              password: bar
              host: localhost
            table:
              name: bar
              primary key: id
          - name: bar
            connection:
              adapter: sqlite3
              database: db/bar.sqlite3
          - name: leet
            connection:
              adapter: sqlite3
              database: db/leet.sqlite3
        transformations:
          functions:
            - name: shazbot
              parameters: [foo, bar, pants]
              ruby: &shazbot "foo / bar - pants + 1337"
              sql:  *shazbot
              type: int
            - name: boo
              parameters: [ghost]
              ruby: &boo "ghost * 5"
              sql:
                mysql: "ghost * 5"
                sqlite3: "ghost * 5"
              type: same as ghost
          resources:
            foo:
              - field: argh
                function: shazbot
                arguments:
                  foo: ahoy
                  bar: matey
                  pants: rum
              - field: blast
                function: renamer
                arguments:
                  from: curses
              - field: avast
                function: trimmer
                arguments:
                  from: avast
              - field: small
                function: downcaser
                arguments:
                  from: medium
        scenarios:
          - name: ninja
            type: self-join
            resource: foo
            matchers:
            - field: blargh
              type: exact
            scoring:
              combining method: mean
              range: '13..37'
          - name: pirate
            type: dual-join
            resources: [foo, bar]
            matchers:
            - fields: [avast, matey]
              type: default
              formula: "rand(100)"
            scoring:
              combining method: sum
              range: '123..456'
      EOF
    end

    def do_parse
      validate(parse_string(@spec.to_yaml))
    end

    def do_ordered_parse(keys)
      hsh = parse_string(@spec.to_yaml)
      sh  = SequencedHash.new
      keys.each { |k| sh[k] = hsh[k].dup }
      validate(sh)
    end

    it "should pass without any changes" do
      x = do_parse
      x.errors.should == []
      x.warnings.should == []
    end

    it "should should pass when out of order" do
      res = do_ordered_parse(%w{transformations resources scenarios})
      res.errors.should == []
    end

    it "should require a map" do
      @spec = %w{hey dude}
      do_parse.should_not be_valid
    end

    describe "/resources" do
      it "should require a sequence of maps" do
        @spec['resources'] = 'bar'
        do_parse.should_not be_valid
      end

      it "should require a name" do
        @spec['resources'].first.delete('name')
        do_parse.should_not be_valid
      end

      it "should require a unique name" do
        @spec['resources'][1]['name'] = 'foo'
        do_parse.should_not be_valid
      end

      it "should require a connection" do
        @spec['resources'].first.delete('connection')
        do_parse.should_not be_valid
      end

      describe "/connection" do
        it "should require an adapter" do
          @spec['resources'].first['connection'].delete('adapter')
          do_parse.should_not be_valid
        end

        it "should require a database" do
          @spec['resources'].first['connection'].delete('database')
          do_parse.should_not be_valid
        end
      end

      it "should not require a table section" do
        @spec['resources'].first.delete('table')
        x = do_parse
        x.errors.should == []
      end

      describe "/table" do
        it "should require a name" do
          @spec['resources'].first['table'].delete('name')
          do_parse.should_not be_valid
        end

        it "should require a primary key" do
          @spec['resources'].first['table'].delete('primary key')
          do_parse.should_not be_valid
        end
      end
    end

    describe "/transformations" do
      it "should be a map" do
        @spec['transformations'] = "pants"
        do_parse.should_not be_valid
      end

      describe "/functions" do
        before(:each) do
          @functions = @spec['transformations']['functions']
        end

        it "should have a name" do
          @functions.first.delete('name')
          do_parse.should_not be_valid
        end

        it "should have a unique name" do
          @functions[1]['name'] = 'shazbot'
          do_parse.should_not be_valid
        end

        it "should bitch if someone tries to use a reserved name" do
          @functions[2] = @functions[1].dup
          @functions[2]['name'] = 'trimmer'
          @spec['transformations']['resources']['foo'].delete_at(2)
          do_parse.should_not be_valid
        end

        it "should have parameters" do
          @functions.first.delete('parameters')
          do_parse.should_not be_valid
        end

        it "should have unique parameters" do
          @functions[0]['parameters'] = %w{foo bar pants foo}
          do_parse.should_not be_valid
        end

        it "should have at least one formula" do
          @functions[0].delete('ruby')
          @functions[0].delete('sql')
          do_parse.should_not be_valid
        end

        it "should have a type" do
          @functions[0].delete('type')
          do_parse.should_not be_valid
        end

        describe "/sql" do
          it "should have valid names when it's a map" do
            @functions[1]['sql'] = {'small' => 'huge'}
            do_parse.should_not be_valid
          end

          it "should not be a sequence" do
            @functions[1]['sql'] = ['small']
            do_parse.should_not be_valid
          end
        end
      end

      describe "/resources" do
        before(:each) do
          @resources = @spec['transformations']['resources']
        end

        it "should be a map" do
          @spec['transformations']['resources'] = "blargh!"
          do_parse.should_not be_valid
        end

        it "should have correct resource names" do
          @resources['blargh'] = @resources.delete('foo')
          do_parse.should_not be_valid
        end

        it "should have a function" do
          @resources['foo'][0].delete('function')
          do_parse.should_not be_valid
        end

        it "should have correct function names" do
          @resources['foo'][0]['function'] = "tiddlywinks"
          do_parse.should_not be_valid
        end

        it "should have a field" do
          @resources['foo'][0].delete('field')
          do_parse.should_not be_valid
        end

        it "should have arguments" do
          @resources['foo'][0].delete('arguments')
          do_parse.should_not be_valid
        end

        it "should require the correct argument names for a function" do
          (a = @resources['foo'][0]['arguments'])['dude'] = a.delete('foo')
          do_parse.should_not be_valid
        end

        it "should complain if there are missing arguments" do
          @resources['foo'][0]['arguments'].delete('foo')
          do_parse.should_not be_valid
        end

        describe "stock functions" do
          describe "trimmer" do
            it "should require the 'from' argument" do
              @resources['foo'][2]['arguments'].delete('from')
              do_parse.should_not be_valid
            end
          end
        end
      end
    end

    describe 'scenarios' do
      before(:each) do
        @scenarios = @spec['scenarios']
      end

      it "should be a sequence" do
        @spec['scenarios'] = "pants"
        do_parse.should_not be_valid
      end

      it "should have a name" do
        @spec['scenarios'][0].delete('name')
        do_parse.should_not be_valid
      end

      it "should have a unique name" do
        @spec['scenarios'][0]['name'] = 'pirate'
        do_parse.should_not be_valid
      end

      it "should have a type" do
        @spec['scenarios'][0].delete('type')
        do_parse.should_not be_valid
      end

      it "should have a valid type" do
        @spec['scenarios'][0]['type'] = 'seamus'
        do_parse.should_not be_valid
      end

      describe "in self-join mode" do
        before(:each) do
          @scenario = @spec['scenarios'][0]
        end

        it "should have a resource" do
          @scenario.delete('resource')
          do_parse.should_not be_valid
        end

        it "should have a correct resource name" do
          @scenario['resource'] = "scrappy_doo"
          do_parse.should_not be_valid
        end
      end

      describe "in dual-join mode" do
        before(:each) do
          @scenario = @spec['scenarios'][1]
        end

        it "should have resources" do
          @scenario.delete('resources')
          do_parse.should_not be_valid
        end

        it "should have exactly two resources" do
          @scenario['resources'] = %w{foo bar leet}
          do_parse.should_not be_valid
        end

        it "should have correct resource names" do
          @scenario['resources'] = %w{scrappy_doo puppy_power}
          do_parse.should_not be_valid
        end
      end

      describe "matchers" do
        before(:each) do
          @matchers_1 = @scenarios[0]['matchers']
          @matchers_2 = @scenarios[1]['matchers']
        end

        it "should be required" do
          @scenarios[0].delete('matchers')
          do_parse.should_not be_valid
        end

        it "should be a sequence" do
          @scenarios[0]['matchers'] = "pants"
          do_parse.should_not be_valid
        end

        it "should have a field if not fields" do
          @matchers_1[0].delete('field')
          do_parse.should_not be_valid
        end

        it "should have fields if not field" do
          @matchers_2[0].delete('fields')
          do_parse.should_not be_valid
        end

        it "should not have both field and fields" do
          @matchers_1[0]['fields'] = %w{yeehaw ride 'em cowboy}
          do_parse.should_not be_valid
        end

        it "should have a type" do
          @matchers_1[0].delete('type')
          do_parse.should_not be_valid
        end

        it "should have a correct type" do
          @matchers_1[0]['type'] = "your mom"
          do_parse.should_not be_valid
        end

        it "should have a formula if type is 'default'" do
          @matchers_2[0].delete('formula')
          do_parse.should_not be_valid
        end

        it "should warn about formula if type is 'exact'" do
          @matchers_1[0]['formula'] = "your mom"
          x = do_parse
          x.warnings.length.should == 1
        end
      end

      describe "scoring" do
        it "should be a map" do
          @scenarios[0]['scoring'] = "foo"
          do_parse.should_not be_valid
        end

        it "should be required" do
          @scenarios[0].delete('scoring')
          do_parse.should_not be_valid
        end

        it "should have a combining method" do
          @scenarios[0]['scoring'].delete('combining method')
          do_parse.should_not be_valid
        end

        it "should have a valid combining method" do
          @scenarios[0]['scoring']['combining method'] = "ugh"
          do_parse.should_not be_valid
        end

        it "should have a range" do
          @scenarios[0]['scoring'].delete('range')
          do_parse.should_not be_valid
        end

        it "should have a valid range" do
          @scenarios[0]['scoring']['range'] = "bad..range"
          do_parse.should_not be_valid
        end
      end
    end
  end
end
