require File.dirname(__FILE__) + "/../spec_helper.rb"

describe Coupler do
  before(:each) do
    @spec    = stub("specification")
    @options = stub("options")
    @runner  = stub("runner", :specification => @spec, :options => @options)
    Coupler::Runner.stub!(:new).and_return(@runner)
    Coupler.instance_variable_set("@runner", nil)
  end

  it "should have a logger" do
    logger = Logger.new(File.dirname(__FILE__) + "/../../log/test.log")
    Coupler.logger = logger
    Coupler.logger.should == logger
  end

  it "should have a specification" do
    Coupler.specification.should == @spec
  end

  it "should have options" do
    Coupler.options.should == @options
  end

  describe ".runner" do
    it "should only create a runner once" do
      Coupler::Runner.should_receive(:new).and_return(@runner)
      Coupler.runner.should == @runner
      Coupler::Runner.should_not_receive(:new).and_return(@runner)
      Coupler.runner.should == @runner
    end
  end
end
