require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Scenario do
  before(:each) do
    @logger = stub(Logger, :debug => nil, :info => nil)
    Coupler.stub!(:logger).and_return(@logger)
  end

  describe 'when self-joining' do
    def create_scenario(spec = {}, opts = {})
      spec = {
        'name'     => 'family', 
        'type'     => 'self-join',
        'resource' => 'birth',
        'transformations' => [
          {
            'name'        => 'MomSSN',
            'transformer' => 'ssn_filter',
            'arguments'   => {'ssn' => 'MomSSN'},
          },
          {
            'name'        => 'MomDOB',
            'transformer' => 'date_changer',
            'arguments'   => {'date' => 'MomDOB'},
          }
        ],
        'matchers' => [
          {
            'field'   => 'MomSSN',
            'formula' => '(!a.nil? && a == b) ? 100 : 0'
          },
          {
            'field'   => 'MomDOB',
            'formula' => '(!a.nil? && a == b) ? 100 : 0'
          }
        ],
        'scoring' => {
          'combining method' => 'mean',
          'range' => '50..100'
        }
      }.merge(spec)
      @options.use_existing_scratch = true   if opts[:use_existing_scratch]
      @options.csv_output = true             if opts[:csv_output]
      Coupler::Scenario.new(spec, @options)
    end

    before(:each) do
      @options      = Coupler::Options.new
      @result       = stub(Coupler::Resource::ResultSet)
      @resource     = stub(Coupler::Resource, :table => "birth_all", :primary_key => "ID", :close => nil)
      @scratch      = stub(Coupler::Resource, :create_table => nil, :insert => nil, :select_one => nil, :drop_table => nil, :set_table_and_key => nil, :close => nil)
      @scores_db    = stub(Coupler::Resource, :create_table => nil, :insert => nil, :select_one => nil, :drop_table => nil, :set_table_and_key => nil, :close => nil)
      @cache        = stub(Coupler::Cache, :add => nil, :fetch => nil, :clear => nil, :auto_fill! => nil)
      @ssn_filter   = stub("ssn transformer", :data_type => 'varchar(9)')
      @date_changer = stub("date transformer", :data_type => 'varchar(10)')
      @matcher      = stub(Coupler::Matchers::MasterMatcher, :add_matcher => nil)
      @resource.stub!(:columns).with(%w{ID MomSSN MomDOB}).and_return({
        "ID" => "int", "MomSSN" => "varchar(9)", "MomDOB" => "date"
      })
      Coupler::Resource.stub!(:find).with('birth').and_return(@resource)
      Coupler::Resource.stub!(:find).with('scratch').and_return(@scratch)
      Coupler::Resource.stub!(:find).with('scores').and_return(@scores_db)
      Coupler::Transformer.stub!(:find).with('ssn_filter').and_return(@ssn_filter)
      Coupler::Transformer.stub!(:find).with('date_changer').and_return(@date_changer)
      Coupler::Matchers::MasterMatcher.stub!(:new).and_return(@matcher)
      Coupler::Cache.stub!(:new).and_return(@cache)
    end

    it "should have a name" do
      s = create_scenario
      s.name.should == 'family'
    end

    it "should have a type of self-join" do
      s = create_scenario
      s.type.should == 'self-join'
    end

    it "should raise an error for an unsupported type" do
      lambda { create_scenario('type' => 'awesome') }.should raise_error("unsupported scenario type")
    end

    it "should find the ssn_filter transformer" do
      Coupler::Transformer.should_receive(:find).with('ssn_filter').and_return(@ssn_filter)
      create_scenario
    end

    it "should find the date_change transformer" do
      Coupler::Transformer.should_receive(:find).with('date_changer').and_return(@date_changer)
      create_scenario
    end

    it "should not find a transformer if it does not relate to matchers" do
      Coupler::Transformer.should_not_receive(:find).with('decepticon').and_return("foo")
      s = create_scenario({
        'transformations' => [
          {
            'name'        => 'foo',
            'transformer' => 'decepticon',
            'arguments'   => {'baz' => 'bar'}
          },
        ]
      })
    end

    it "should raise an error if it can't find a transformer" do
      Coupler::Transformer.stub!(:find).and_return(nil)
      lambda { create_scenario }.should raise_error("can't find transformer 'ssn_filter'")
    end

    it "should find the birth resource" do
      Coupler::Resource.should_receive(:find).with('birth').and_return(@resource)
      create_scenario
    end

    it "should find the scratch resource" do
      Coupler::Resource.should_receive(:find).with('scratch').and_return(@scratch)
      create_scenario
    end

    it "should find the scores resource" do
      Coupler::Resource.should_receive(:find).with('scores').and_return(@scores_db)
      create_scenario
    end

    it "should raise an error if it can't find the resource" do
      Coupler::Resource.stub!(:find).and_return(nil)
      lambda { create_scenario }.should raise_error("can't find resource 'birth'")
    end

    it "should not raise an error if there are no transformations" do
      create_scenario('transformations' => nil)
    end

    it "should create a master matcher" do
      Coupler::Matchers::MasterMatcher.should_receive(:new).with({
        'field list' => %w{ID MomSSN MomDOB},
        'combining method' => 'mean',
        'range' => 50..100,
        'cache' => @cache,
        'resource' => @scratch,
        'scores' => @scores_db,
        'name' => 'family'
      }, @options).and_return(@matcher)
      create_scenario
    end

    it "should add the SSN matcher" do
      @matcher.should_receive(:add_matcher).with('field' => 'MomSSN', 'formula' => '(!a.nil? && a == b) ? 100 : 0')
      create_scenario
    end

    it "should add the DOB matcher" do
      @matcher.should_receive(:add_matcher).with('field' => 'MomDOB', 'formula' => '(!a.nil? && a == b) ? 100 : 0')
      create_scenario
    end

    it "should create a cache with the scratch database" do
      Coupler::Cache.should_receive(:new).with('scratch', @options).and_return(@cache)
      create_scenario
    end

    it "should use a guaranteed cache when specified in the YAML" do
      Coupler::Cache.should_receive(:new).with('scratch', @options, 1000).and_return(@cache)
      create_scenario('guarantee' => 1000)
    end

    it "should grab field info from the resource" do
      @resource.should_receive(:columns).with(%w{ID MomSSN MomDOB}).and_return({
        "ID" => "int", "MomSSN" => "varchar(9)", "MomDOB" => "date"
      })
      create_scenario
    end

    describe "#run" do
      
      def do_run(options = {})
        if @run_options
          create_scenario(@run_options.merge(options)).run
        else
          create_scenario(options).run
        end
      end

      before(:each) do
        @date_1 = Date.parse('1982-4-15')
        @date_2 = Date.parse('1980-9-4')

        # resource setup
        @all_result = stub("ResultSet (all)", :close => nil)
        @all_result.stub!(:next).and_return(
          [1, "123456789", @date_1],
          [2, "999999999", @date_2],
          [3, "123456789", @date_1],
          [4, "123456789", @date_2],
          nil
        )
        @resource.stub!(:select).with({
          :columns => ["ID", "MomSSN", "MomDOB"], :order => "ID",
          :limit => 10000, :offset => 0
        }).and_return(@all_result)
        @resource.stub!(:count).and_return(4)

        # transformer setup
        @ssn_filter.stub!(:transform).with('ssn' => '123456789').and_return('123456789')
        @ssn_filter.stub!(:transform).with('ssn' => '999999999').and_return(nil)
        @date_changer.stub!(:transform).with('date' => @date_1).and_return(@date_1.to_s)
        @date_changer.stub!(:transform).with('date' => @date_2).and_return(@date_2.to_s)

        # matcher setup
        @scores = stub(Coupler::Scores)
        @matcher.stub!(:score).and_return(@scores)
        [[1, 3, 100], [1, 4, 50], [2, 4, 50], [3, 4, 50]].inject(@scores.stub!(:each)) do |s, ary|
          s.and_yield(*ary)
        end
      end

      describe "when using an already existing scratch database" do
        before(:each) do
          @scenario =  create_scenario({}, {:use_existing_scratch => true})
        end

        it "should not drop any tables from the scratch database" do
          @scratch.should_not_receive(:drop_table)
          @scenario.run
        end

        it "should not create any tables in the scratch database" do
          @scratch.should_not_receive(:create_table)
          @scenario.run
        end

        it "should not transform any records" do
          @ssn_filter.should_not_receive(:transform).and_return(nil)
          @date_change.should_not_receive(:transform).and_return(nil)
          @scenario.run
        end

        it "should auto-fill the cache" do
          @cache.should_receive(:auto_fill!)
          @scenario.run
        end

        it "should not auto-fill the cache if all matchers are exact" do
          @cache.should_not_receive(:auto_fill!)
          s = create_scenario({
            'matchers' => [
              {'field' => 'MomSSN', 'type' => 'exact'},
              {'field' => 'MomDOB', 'type' => 'exact'}
            ]
          }, {:use_existing_scratch => true})
          s.run
        end

        it "should set the table and key of the scratch resource" do
          @scratch.should_receive(:set_table_and_key).with('birth_all', 'ID')
          @scenario.run
        end
      end

      describe "when outputting csv's" do
        before(:each) do
          @scenario = create_scenario({}, :csv_output => true)
        end

        it "should output results in the result file" do
          expected = [
            %w{id1 id2 score},
            %w{1 3 100},
            %w{1 4 50},
            %w{2 4 50},
            %w{3 4 50}
          ]
          @scenario.run

          File.exist?("family.csv").should be_true
          FasterCSV.foreach("family.csv") do |row|
            row.should == expected.shift
          end
          expected.should be_empty
          File.delete("family.csv")
        end
      end

      describe "when --db-limit 50000" do
        before(:each) do
          @options.db_limit = 50000
          @resource.stub!(:select).with({
            :columns => ["ID", "MomSSN", "MomDOB"], :order => "ID",
            :limit => 50000, :offset => 0
          }).and_return(@all_result)
        end

        it "should select 50000 records at a time" do
          @resource.should_receive(:select).with({
            :columns => ["ID", "MomSSN", "MomDOB"], :order => "ID",
            :limit => 50000, :offset => 0
          }).and_return(@all_result)
          s = create_scenario
          s.run
        end

        it "should insert at most 50000 records into scratch at a time when --db-limit 50000" do
          # this is a crappy way to test this
          scenario = create_scenario
          buff = scenario.instance_variable_get("@transform_buffer")
          buff.stub!(:length).and_return(50000)  # hackery
          fields = %w{ID MomSSN MomDOB}
          @scratch.should_receive(:insert).with(fields, [1, "123456789", "1982-04-15"])
          @scratch.should_receive(:insert).with(fields, [2, nil, "1980-09-04"])
          @scratch.should_receive(:insert).with(fields, [3, "123456789", "1982-04-15"])
          @scratch.should_receive(:insert).with(fields, [4, "123456789", "1980-09-04"])
          scenario.run
        end
      end

      it "should clear the cache" do
        @cache.should_receive(:clear)
        do_run
      end

      it "should log the start of the run" do
        @logger.should_receive(:info).with("Scenario (family): Run start")
        do_run
      end

      it "should count number of records" do
        @resource.should_receive(:count).and_return(4)
        do_run
      end

      it "should select all needed fields for 10000 records at a time" do
        @resource.should_receive(:select).with({
          :columns => ["ID", "MomSSN", "MomDOB"], :order => "ID",
          :limit => 10000, :offset => 0
        }).and_return(@all_result)
        s = create_scenario
        s.run
      end
      
      it "should select only certain records if given conditions" do
        @resource.should_receive(:select).with({
          :columns => %w{ID MomSSN MomDOB}, :limit => 10000,
          :conditions => "MomSSN NOT IN ('111111111', '222222222')",
          :offset => 0, :order => 'ID'
        }).and_return(@all_result)
        do_run('conditions' => "MomSSN NOT IN ('111111111', '222222222')")
      end

      it "should select fields needed to transform a matcher field" do
        # stub transformer
        convoy = stub("optimus prime is called convoy in japan", :data_type => 'varchar(255)')
        convoy.stub!(:transform).and_return("optimus-prime")
        Coupler::Transformer.stub!(:find).with('convoy').and_return(convoy)
        @resource.should_receive(:select).with({
          :columns => %w{ID MomDOB junk MomSSN},
          :order => "ID", :limit => 10000, :offset => 0
        }).and_return(@all_result)
        s = create_scenario({
          'transformations' => [{
            'name' => 'MomSSN', 'transformer' => 'convoy',
            'arguments' => { 'ssn' => 'MomSSN', 'stuff' => 'junk' }
          }]
        })
        s.run
      end

      it "should not select fields not in the database" do
        baka = stub("some crappy transformer", :data_type => 'varchar(255)', :transform => "baka")
        Coupler::Transformer.stub!(:find).with('baka').and_return(baka)
        @resource.should_receive(:select).with({
          :columns => %w{ID MomSSN MomDOB},
          :order => "ID", :limit => 10000, :offset => 0
        }).and_return(@all_result)
        create_scenario({
          'transformations' => [{
            'name' => 'saru', 'transformer' => 'baka',
            'arguments' => { 'ssn' => 'MomSSN', 'dob' => 'MomDOB' }
          }]
        }).run
      end

      it "should transform the first record" do
        @ssn_filter.should_receive(:transform).with('ssn' => '123456789').at_least(1).times.and_return('123456789')
        @date_changer.should_receive(:transform).with('date' => @date_1).at_least(1).times.and_return(@date_1.to_s)
        s = create_scenario
        s.run
      end

      it "should drop the table from the scratch resource" do
        @scratch.should_receive(:drop_table).with("birth_all")
        do_run
      end

      it "should setup the scratch resource with all needed columns" do
        @scratch.should_receive(:create_table).with("birth_all", ["ID int", "MomSSN varchar(9)", "MomDOB varchar(10)"], [])
        s = create_scenario
        s.run
      end

      it "should name the scratch table something unique, like the name of the scenario"

      it "should setup the scratch resource properly even if the first record has nil values" do
        @all_result.stub!(:next).and_return(
          [1, "999999999", @date_2],
          [2, "123456789", @date_1],
          [3, "123456789", @date_1],
          [4, "123456789", @date_2],
          nil
        )
        @scratch.should_receive(:create_table).with("birth_all", ["ID int", "MomSSN varchar(9)", "MomDOB varchar(10)"], [])
        s = create_scenario
        s.run
      end

      it "should create an index on the scratch resource for exact matchers" do
        @scratch.should_receive(:create_table).with("birth_all", ["ID int", "MomSSN varchar(9)", "MomDOB varchar(10)"], ["MomDOB"])
        s = create_scenario({
          'matchers' => [
            {'field'   => 'MomSSN', 'formula' => '(!a.nil? && a == b) ? 100 : 0'},
            {'field'   => 'MomDOB', 'type'    => 'exact'}
          ]
        })
        s.run
      end

      it "should set up indices properly for an exact matcher with multiple fields" do
        @scratch.should_receive(:create_table).with(
          "birth_all", ["ID int", "MomSSN varchar(9)", "MomDOB varchar(10)"],
          [%w{MomSSN MomDOB}]
        )
        s = create_scenario({
          'matchers' => [{'fields' => %w{MomSSN MomDOB}, 'type' => 'exact'}]
        })
        s.run
      end

      it "should not add fields to scratch that aren't needed" do
        baka = stub("some crappy transformer", :data_type => 'varchar(1337)', :transform => "123456789")
        Coupler::Transformer.stub!(:find).with('baka').and_return(baka)
        @all_result.stub!(:next).and_return(
          [1, @date_1, "foo", "bar"],
          [2, @date_2, "foo", "bar"],
          [3, @date_1, "foo", "bar"],
          [4, @date_2, "foo", "bar"],
          nil
        )
        @resource.stub!(:select).with({
          :columns => %w{ID MomDOB some_field some_other_field},
          :order => "ID", :limit => 10000, :offset => 0
        }).and_return(@all_result)
        @scratch.should_receive(:create_table).with("birth_all", ["ID int", "MomSSN varchar(1337)", "MomDOB date"], [])
        create_scenario({
          'transformations' => [{
            'name' => 'MomSSN', 'transformer' => 'baka',
            'arguments' => { 'field1' => 'some_field', 'field2' => 'some_other_field' }
          }]
        }).run
      end

      it "should transform the other records" do
        @ssn_filter.should_receive(:transform).with('ssn' => '123456789').exactly(3).times.and_return('123456789')
        @date_changer.should_receive(:transform).with('date' => @date_1).twice.and_return(@date_1.to_s)
        @date_changer.should_receive(:transform).with('date' => @date_2).twice.and_return(@date_2.to_s)
        s = create_scenario
        s.run
      end

      it "should insert the transformed records into scratch" do
        fields = %w{ID MomSSN MomDOB}
        @scratch.should_receive(:insert).with(
          fields, 
          [1, "123456789", "1982-04-15"], [2, nil, "1980-09-04"],
          [3, "123456789", "1982-04-15"], [4, "123456789", "1980-09-04"]
        )
        s = create_scenario
        s.run
      end

      it "should insert at most 10000 records into scratch at a time" do
        # this is a crappy way to test this
        scenario = create_scenario
        buff = scenario.instance_variable_get("@transform_buffer")
        buff.stub!(:length).and_return(10000)  # hackery
        fields = %w{ID MomSSN MomDOB}
        @scratch.should_receive(:insert).with(fields, [1, "123456789", "1982-04-15"])
        @scratch.should_receive(:insert).with(fields, [2, nil, "1980-09-04"])
        @scratch.should_receive(:insert).with(fields, [3, "123456789", "1982-04-15"])
        @scratch.should_receive(:insert).with(fields, [4, "123456789", "1980-09-04"])
        scenario.run
      end

      it "should add the records into the cache" do
        @cache.should_receive(:add).with(2, [2, nil, "1980-09-04"])
        @cache.should_receive(:add).with(3, [3, "123456789", "1982-04-15"])
        @cache.should_receive(:add).with(4, [4, "123456789", "1980-09-04"])
        do_run
      end

      it "should not add records into the cache if all matchers are exact" do
        @cache.should_not_receive(:add)
        s = create_scenario({
          'matchers' => [
            {'field' => 'MomSSN', 'type' => 'exact'},
            {'field' => 'MomDOB', 'type' => 'exact'}
          ]
        })
        s.run
      end

      it "should select 10000 more records if it runs out" do
        result1 = stub("first 10000", :close => nil)
        result1.stub!(:next).and_return([1, "123456789", @date_1], [2, "999999999", @date_2], nil)
        result2 = stub("second 10000", :close => nil)
        result2.stub!(:next).and_return([3, "123456789", @date_1], [4, "123456789", @date_2], nil)

        @resource.stub!(:count).and_return(20000)
        @resource.should_receive(:select).with({
          :columns => ["ID", "MomSSN", "MomDOB"], :order => "ID",
          :limit => 10000, :offset => 0
        }).and_return(result1)
        @resource.should_receive(:select).with({
          :columns => ["ID", "MomSSN", "MomDOB"], :order => "ID",
          :limit => 10000, :offset => 10000
        }).and_return(result2)
        do_run
      end

      it "should not be boned if there are no transformers" do
        do_run('transformations' => nil)
      end

      it "should match all records" do
        @matcher.should_receive(:score).with(no_args()).and_return(@scores)
        s = create_scenario
        s.run
      end
    end
  end
end
