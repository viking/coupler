require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Runner do
  before(:each) do
    @options     = Coupler::Options.new
    @filenames   = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/sauce.yml")]
    @scores      = stub(Coupler::Scores)
    @scores.stub!(:each).and_yield(1, 2, 100).and_yield(1, 3, 85).and_yield(1, 4, 60)

    @leet_set = stub("leetsauce records", :next => nil, :close => nil)
    @weak_set = stub("weaksauce records", :next => nil, :close => nil)
    @may_set  = stub("mayhem records", :next => nil, :close => nil)
    @leet_buf = stub("insert buffer for leetsauce", :flush! => nil, :<< => nil)
    @weak_buf = stub("insert buffer for weaksauce", :flush! => nil, :<< => nil)
    @may_buf  = stub("insert buffer for mayhem", :flush! => nil, :<< => nil)
    @resources = {
      :scores    => stub("scores resource",    :name => 'scores'),
      :scratch   => stub("scratch resource",   :name => 'scratch', :create_table => nil, :drop_table => nil),
      :leetsauce => stub("leetsauce resource", :name => 'leetsauce', :select => @leet_set, :primary_key => "id"),
      :weaksauce => stub("weaksauce resource", :name => 'weaksauce', :select => @weak_set, :primary_key => "id"),
      :mayhem    => stub("mayhem resource",    :name => 'mayhem',    :select => @may_set,  :primary_key => "id"),
    }
    @resources[:scratch].stub!(:insert_buffer).with(%w{id foo bar zoidberg}).and_return(@leet_buf)
    @resources[:scratch].stub!(:insert_buffer).with(%w{id foo nixon}).and_return(@weak_buf)
    @resources[:scratch].stub!(:insert_buffer).with(%w{id pants shirt}).and_return(@may_buf)
    @resources.each_pair do |name, obj|
      Coupler::Resource.stub!(:new).with(hash_including('name' => name.to_s), @options).and_return(obj)
    end

    # this is a little excessive :(
    @scenarios = {
      :leetsauce_foo => stub("leetsauce_foo scenario", {
        :name => 'leetsauce_foo', :resource => @resources[:leetsauce],
        :field_list => %w{id foo bar}, :indices => [%w{foo bar}], :run => @scores
      }),
      :leetsauce_bar => stub("leetsauce_bar scenario", {
        :name => 'leetsauce_bar', :resource => @resources[:leetsauce],
        :field_list => %w{id foo zoidberg}, :indices => [%w{foo zoidberg}], :run => @scores
      }),
      :weaksauce_foo => stub("weaksauce_foo scenario", {
        :name => 'weaksauce_foo', :resource => @resources[:weaksauce],
        :field_list => %w{id foo nixon}, :indices => %w{foo nixon}, :run => @scores 
      }),
      :utter_mayhem => stub("utter_mayhem scenario", {
        :name => 'utter_mayhem', :resource => @resources[:mayhem],
        :field_list => %w{id pants shirt}, :indices => %w{pants shirt}, :run => @scores 
      })
    }
    @scenarios.each_pair do |name, obj|
      Coupler::Scenario.stub!(:new).with(hash_including('name' => name.to_s), @options).and_return(obj)
    end

    @transformers = {
      :foo_filter => stub("foo_filter", :data_type => "varchar(9)"),
      :bar_bender => stub("bar_bender", :data_type => "int")
    }
    %w{foo_filter bar_bender}.each do |name|
      Coupler::Transformer.stub!(:new).with(hash_including('name' => name)).and_return(@transformers[name.to_sym])
    end
  end

  def create_runner
    Coupler::Runner.new(YAML.load_file(@filenames[0]), @options)
  end

  it "should create a new resource for each item in 'resources'" do
    @resources.each_pair do |name, obj|
      Coupler::Resource.should_receive(:new).with(hash_including('name' => name.to_s), @options).and_return(obj)
    end
    create_runner
  end

  it "should create a new transformer for each item in 'transformers'" do
    %w{foo_filter bar_bender}.each do |name|
      Coupler::Transformer.should_receive(:new).with(
        hash_including('name' => name)
      ).and_return(@transformers[name.to_sym])
    end
    create_runner
  end

  it "should create a new scenario for each item in 'scenarios'" do
    @scenarios.each_pair do |name, obj|
      Coupler::Scenario.should_receive(:new).with(hash_including('name' => name.to_s), @options).and_return(obj)
    end
    create_runner
  end

  it "should require a scratch database resource" do
    @filenames = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/no-scratch.yml")]
    lambda { create_runner }.should raise_error
  end

  it "should require a scores database resource" do
    @filenames = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/no-scores.yml")]
    lambda { create_runner }.should raise_error
  end

  it "should not freak if there are no transformers" do
    @filenames = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/no-transformers.yml")]
    lambda { create_runner }.should_not raise_error
  end

  describe ".run" do
    before(:each) do
      @options.filenames = @filenames
      @runner = stub("runner", :run => nil)
      Coupler::Runner.stub!(:new).and_return(@runner)
    end

    it "should create a new Runner" do 
      Coupler::Runner.should_receive(:new).with(YAML.load_file(@filenames[0]), @options).and_return(@runner)
      Coupler::Runner.run(@options)
    end

    it "should run the runner" do
      @runner.should_receive(:run)
      Coupler::Runner.run(@options)
    end
    
    it "should pass spec filenames that end in .erb through erubis" do
      # erb rendered version is the same as non-erb version
      spec = YAML.load_file(@filenames.first)
      @filenames.first << '.erb'
      Coupler::Runner.should_receive(:new).with(spec, @options).and_return(@runner)
      Coupler::Runner.run(@options)
    end

    it "should accept a specification hash" do
      spec = YAML.load_file(@filenames.first)
      spec['resources'][0]['table']['name'] = "leetasaurus"
      Coupler::Runner.should_receive(:new).with(spec, @options).and_return(@runner)
      Coupler::Runner.run(spec, @options)
    end
  end

  describe "#run" do
    before(:each) do
      @runner = Coupler::Runner.new(YAML.load_file(@filenames[0]), @options)
    end
    it "should run each scenario" do
      @scenarios.values.each do |scenario|
        scenario.should_receive(:run).and_return(@scores)
      end
      @runner.run
    end
  end

  describe ".transform" do
    before(:each) do
      @options.filenames = @filenames
      @runner = stub("runner", :transform => nil)
      Coupler::Runner.stub!(:new).and_return(@runner)
    end

    it "should create a new Runner" do 
      Coupler::Runner.should_receive(:new).with(YAML.load_file(@filenames[0]), @options).and_return(@runner)
      Coupler::Runner.transform(@options)
    end

    it "should call transform on the runner" do
      @runner.should_receive(:transform)
      Coupler::Runner.transform(@options)
    end
  end

  describe "#transform" do
    before(:each) do
      @resources[:leetsauce].stub!(:columns).and_return({'id' => 'int', 'zoidberg' => 'int'})
      @resources[:weaksauce].stub!(:columns).and_return({'id' => 'int', 'nixon' => 'int'})
      @resources[:mayhem].stub!(:columns).and_return({'id' => 'int', 'pants' => 'varchar(7)', 'shirt' => 'varchar(8)'})
      @leet_set.stub!(:next).and_return(
        [1, "123456789", 10, 10], [2, "234567891", 20, 20], [3, "345678912", 30, 30],
        [4, "444444444", 40, 40], [5, "567891234", 50, 50], nil
      )
      @weak_set.stub!(:next).and_return(
        [1, "111111111", 100], [2, "222222222", 200], [3, "333333333", 300],
        [4, "456789123", 400], [5, "555555555", 500], nil
      )
      @may_set.stub!(:next).and_return(
        [1, "khakis", "polo"], [2, "jeans", "t-shirt"], [3, "skirt", "blouse"],
        [4, "shorts", "tanktop"], [5, "trunks", "none"], nil
      )
      @transformers[:foo_filter].stub!(:transform).and_return("convoy")
      @transformers[:bar_bender].stub!(:transform).and_return(1337)

      @runner = Coupler::Runner.new(YAML.load_file(@filenames[0]), @options)
    end

    describe "when using pre-existing scratch tables" do
      before(:each) do
        @options.use_existing_scratch = true
      end

      it "should not drop any tables" do
        @resources[:scratch].should_not_receive(:drop_table)
        @runner.transform
      end

      it "should not create any tables" do
        @resources[:scratch].should_not_receive(:create_table)
        @runner.transform
      end
    end

    it "should drop pre-existing scratch tables" do
      @resources[:scratch].should_receive(:drop_table).with('leetsauce')
      @resources[:scratch].should_receive(:drop_table).with('weaksauce')
      @resources[:scratch].should_receive(:drop_table).with('mayhem')
      @runner.transform
    end

    it "should get column info about all non-transformer fields" do
      @resources[:leetsauce].should_receive(:columns).and_return({'id' => 'int', 'zoidberg' => 'int'})
      @resources[:weaksauce].should_receive(:columns).and_return({'id' => 'int', 'nixon' => 'int'})
      @resources[:mayhem].should_receive(:columns).and_return({'id' => 'int', 'pants' => 'varchar(7)', 'shirt' => 'varchar(8)'})
      @runner.transform
    end

    it "should create one scratch table for each resource used" do
      @resources[:scratch].should_receive(:create_table).with( 
        'leetsauce', ["id int", "foo varchar(9)", "bar int", "zoidberg int"], 
        [["foo", "bar"], ["foo", "zoidberg"]]
      )
      @resources[:scratch].should_receive(:create_table).with( 
        'weaksauce', ["id int", "foo varchar(9)", "nixon int"], ["foo", "nixon"]
      )
      @resources[:scratch].should_receive(:create_table).with( 
        'mayhem', ["id int", "pants varchar(7)", "shirt varchar(8)"], ["pants", "shirt"]
      )
      @runner.transform
    end

    # this happens anyway through the resource, although the error message won't be that clear
#      it "should complain if there are conflicting schema columns" do
#        @scenario_2.stub!(:scratch_schema).and_return({
#          :fields  => ["id int", "name varchar(13)", "age int"],
#          :indices => []
#        })
#        lambda { @runner.setup_scratch_database }.should raise_error("conflicting types for column 'name'")
#      end

    it "should select all needed fields from leetsauce" do
      @resources[:leetsauce].should_receive(:select) do |hsh|
        hsh[:auto_refill].should be_true
        (%w{id foo zoidberg nixon} - hsh[:columns]).should be_empty
        hsh[:order].should == "id"
        @leet_set
      end
      @runner.transform
    end

    it "should select all needed fields from weaksauce" do
      @resources[:weaksauce].should_receive(:select) do |hsh|
        hsh[:auto_refill].should be_true
        (%w{id foo nixon} - hsh[:columns]).should == []
        hsh[:order].should == "id"
        @weak_set
      end
      @runner.transform
    end

    it "should select all needed fields from mayhem" do
      @resources[:mayhem].should_receive(:select) do |hsh|
        hsh[:auto_refill].should be_true
        (%w{id pants shirt} - hsh[:columns]).should == []
        hsh[:order].should == "id"
        @may_set
      end
      @runner.transform
    end

    it "should transform all records in leetsauce" do
      expected_foo = %w{123456789 234567891 345678912 444444444 567891234}.collect { |s| {'string' => s } }
      @transformers[:foo_filter].should_receive(:transform).at_least(5).times do |args|
        expected_foo.delete(args)
        args['string'] =~ /4{9}/ ? nil : args['string']
      end

      expected_bar = (1..5).collect { |i| {'fry' => i*10, 'leela' => i*10} }
      @transformers[:bar_bender].should_receive(:transform).at_least(5).times do |args|
        expected_bar.delete(args)
        args['fry'] < 10 ? args['leela'] * 10 : args['fry'] / 5
      end

      @runner.transform
      expected_foo.should == []
      expected_bar.should == []
    end

    it "should transform all records in weaksauce" do
      expected_foo = %w{111111111 222222222 333333333 456789123 555555555}.collect { |s| {'string' => s } }
      @transformers[:foo_filter].should_receive(:transform).at_least(5).times do |args|
        expected_foo.delete(args)
        args['string'][0..2] == "456" ? args['string'] : nil
      end

      @runner.transform
      expected_foo.should == []
    end

    it "should create an insert buffer from the scratch resource for each resource" do
      @resources[:scratch].should_receive(:insert_buffer).with(%w{id foo bar zoidberg}).and_return(@leet_buf)
      @resources[:scratch].should_receive(:insert_buffer).with(%w{id foo nixon}).and_return(@weak_buf)
      @resources[:scratch].should_receive(:insert_buffer).with(%w{id pants shirt}).and_return(@may_buf)
      @runner.transform
    end

    it "should add each transformed leetsauce record to the insert buffer" do
      @leet_buf.should_receive(:<<).with([1, "convoy", 1337, 10])
      @leet_buf.should_receive(:<<).with([2, "convoy", 1337, 20])
      @leet_buf.should_receive(:<<).with([3, "convoy", 1337, 30])
      @leet_buf.should_receive(:<<).with([4, "convoy", 1337, 40])
      @leet_buf.should_receive(:<<).with([5, "convoy", 1337, 50])
      @runner.transform
    end

    it "should add each transformed weaksauce record to the insert buffer" do
      @weak_buf.should_receive(:<<).with([1, "convoy", 100])
      @weak_buf.should_receive(:<<).with([2, "convoy", 200])
      @weak_buf.should_receive(:<<).with([3, "convoy", 300])
      @weak_buf.should_receive(:<<).with([4, "convoy", 400])
      @weak_buf.should_receive(:<<).with([5, "convoy", 500])
      @runner.transform
    end

    it "should add each mayhem record as-is to the insert buffer" do
      @may_buf.should_receive(:<<).with([1, "khakis", "polo"])
      @may_buf.should_receive(:<<).with([2, "jeans", "t-shirt"])
      @may_buf.should_receive(:<<).with([3, "skirt", "blouse"])
      @may_buf.should_receive(:<<).with([4, "shorts", "tanktop"])
      @may_buf.should_receive(:<<).with([5, "trunks", "none"])
      @runner.transform
    end
    
    it "should flush the insert buffers" do
      @leet_buf.should_receive(:flush!)
      @weak_buf.should_receive(:flush!)
      @may_buf.should_receive(:flush!)
      @runner.transform
    end
  end
end
