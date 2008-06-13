require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Runner do
  describe ".run" do
    before(:each) do
      @results = stub(Linkage::Scores)
      @results.stub!(:each).and_yield(1, 2, 100).and_yield(1, 3, 85).and_yield(1, 4, 60)
      @options = Linkage::Options.new
      @filenames = [File.expand_path(File.dirname(__FILE__) + "/../../fixtures/family.yml")]
      @resource    = stub(Linkage::Resource)
      @transformer = stub(Linkage::Transformer)
      @scenario_1  = stub(Linkage::Scenario, :name => "uno", :run => @results)
      @scenario_2  = stub(Linkage::Scenario, :name => "dos", :run => @results)
      Linkage::Resource.stub!(:new).and_return(@resource)
      Linkage::Transformer.stub!(:new).and_return(@transformer)
      Linkage::Scenario.stub!(:new).twice.and_return(@scenario_1, @scenario_2)
    end

    def do_run
      @options.filenames = @filenames
      Linkage::Runner.run(@options)
    end

    it "should accept a filename as an argument" do
      do_run
    end

    it "should create a new resource for each item in 'resources'" do
      Linkage::Resource.should_receive(:new).exactly(4).times.and_return(@resource)
      do_run
    end

    it "should create a new transformer for each item in 'transformers'" do
      Linkage::Transformer.should_receive(:new).twice.and_return(@transformer)
      do_run
    end

    it "should create a new scenario for each item in 'scenarios'" do
      Linkage::Scenario.should_receive(:new).with(an_instance_of(Hash), @options).twice.and_return(@scenario_1, @scenario_2)
      do_run
    end

    it "should run each scenario" do
      @scenario_1.should_receive(:run).and_return(@results)
      @scenario_2.should_receive(:run).and_return(@results)
      do_run
    end

    it "should create a result file for each scenario" do
      do_run
      File.exist?('uno.csv').should be_true
      File.exist?('dos.csv').should be_true
    end

    it "should output results in the result file" do
      expected = [
        %w{id1 id2 score},
        %w{1 2 100},
        %w{1 3 85},
        %w{1 4 60}
      ]
      do_run

      FasterCSV.foreach("uno.csv") do |row|
        row.should == expected.shift
      end
      expected.should be_empty
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

    after(:each) do
      File.delete('uno.csv')  if File.exist?('uno.csv')
      File.delete('dos.csv')  if File.exist?('dos.csv')
    end
  end
end
