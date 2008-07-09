require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Runner do
  before(:each) do
    @options     = Coupler::Options.new
    @filenames   = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/family.yml")]
    @result_set  = stub("result set", :next => nil, :close => nil)
    @resources   = {
      :generic   => stub("generic resource", :name => 'generic'),
      :scratch   => stub("scratch resource", :name => 'scratch', :create_table => nil, :drop_table => nil, :insert => nil),
      :leetsauce => stub("leetsauce resource", :name => 'leetsauce', :select_with_refill => @result_set),
      :weaksauce => stub("weaksauce resource", :name => 'weaksauce', :select_with_refill => @result_set),
    }

    %w{birth death scratch scores}.each do |name|
      Coupler::Resource.stub!(:new).with(
        hash_including('name' => name), @options
      ).and_return(@resources[name == 'scratch' ? :scratch : :generic])
    end

    @results     = stub(Coupler::Scores)
    @transformer = stub(Coupler::Transformer)
    @scenario_1  = stub(Coupler::Scenario, :name => "uno", :run => @results, :resource => @resources[:leetsauce], :transform => nil)
    @scenario_2  = stub(Coupler::Scenario, :name => "dos", :run => @results, :resource => @resources[:leetsauce], :transform => nil)
    @results.stub!(:each).and_yield(1, 2, 100).and_yield(1, 3, 85).and_yield(1, 4, 60)

    Coupler::Transformer.stub!(:new).and_return(@transformer)
    Coupler::Scenario.stub!(:new).twice.and_return(@scenario_1, @scenario_2)
  end

  describe ".run" do
    def do_run
      @options.filenames = @filenames
      Coupler::Runner.run(@options)
    end

    it "should accept a filename as an argument" do
      do_run
    end

    it "should create a new resource for each item in 'resources'" do
      %w{birth death scratch scores}.each do |name|
        Coupler::Resource.should_receive(:new).with(
          hash_including('name' => name), @options
        ).and_return(@resources[name == 'scratch' ? :scratch : :generic])
      end
      do_run
    end

    it "should create a new transformer for each item in 'transformers'" do
      Coupler::Transformer.should_receive(:new).twice.and_return(@transformer)
      do_run
    end

    it "should create a new scenario for each item in 'scenarios'" do
      Coupler::Scenario.should_receive(:new).with(an_instance_of(Hash), @options).twice.and_return(@scenario_1, @scenario_2)
      do_run
    end

    it "should run each scenario" do
      @scenario_1.should_receive(:run).and_return(@results)
      @scenario_2.should_receive(:run).and_return(@results)
      do_run
    end

    it "should require a scratch database resource" do
      @filenames = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/no-scratch.yml")]
      lambda { do_run }.should raise_error
    end

    it "should require a scores database resource" do
      @filenames = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/no-scores.yml")]
      lambda { do_run }.should raise_error
    end

    it "should not freak if there are no transformers" do
      @filenames = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/no-transformers.yml")]
      lambda { do_run }.should_not raise_error
    end
  end

  describe ".transform" do
    before(:each) do
      @runner = stub("runner", :setup_scratch_database => nil, :transform => nil)
      Coupler::Runner.stub!(:new).and_return(@runner)
    end

    def do_xform
      @options.filenames = @filenames
      Coupler::Runner.transform(@options)
    end

    it "should create a new Runner" do 
      Coupler::Runner.should_receive(:new).with(YAML.load_file(@filenames[0]), @options).and_return(@runner)
      do_xform
    end

    it "should call transform on the runner" do
      @runner.should_receive(:transform)
      do_xform
    end
  end

  describe "#transform" do
    before(:each) do
      @scenario_1.stub!(:scratch_schema).and_return({
        :fields  => ["id int", "pants int", "shirts int", "name varchar(10)"],
        :indices => []
      })
      @scenario_2.stub!(:scratch_schema).and_return({
        :fields  => ["id int", "name varchar(10)", "age int"],
        :indices => []
      })
      @resources[:weaksauce].stub!(:count).and_return(5)
      @resources[:leetsauce].stub!(:count).and_return(5)
      @result_set.stub!(:next).and_return([1], [2], [3], [4], [5], nil)
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
      @runner.transform
    end

    it "should create scratch tables based on all scenarios" do
      @resources[:scratch].should_receive(:create_table).with( 
        'leetsauce', 
        ["id int", "pants int", "shirts int", "name varchar(10)", "age int"],
        []
      )
      @runner.transform
    end

    it "should create two scratch tables if there are two different total resources" do
      @scenario_2.stub!(:resource).and_return(@resources[:weaksauce])
      @resources[:scratch].should_receive(:create_table).with( 
        'leetsauce', 
        ["id int", "pants int", "shirts int", "name varchar(10)"],
        []
      )
      @resources[:scratch].should_receive(:create_table).with( 
        'weaksauce', ["id int", "name varchar(10)", "age int"], []
      )
      @result_set.stub!(:next).and_return([1])
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

    it "should prep the scratch resource by inserting id's" do
      @resources[:leetsauce].should_receive(:select_with_refill).with(:columns => %w{id}).and_return(@result_set)
      @resources[:scratch].should_receive(:insert).with(%w{id}, [1], [2], [3], [4], [5])
      @runner.transform
    end

    it "should insert id's according to the --db_limit option" do
      @options.db_limit = 3
      @resources[:scratch].should_receive(:insert).with(%w{id}, [1], [2], [3])
      @resources[:scratch].should_receive(:insert).with(%w{id}, [4], [5])
      @runner.transform
    end
    
    it "should call transform on each scenario" do
      @scenario_1.should_receive(:transform)
      @scenario_2.should_receive(:transform)
      @runner.transform
    end
  end
end
