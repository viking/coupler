require File.dirname(__FILE__) + "/../spec_helper.rb"

describe Coupler do
  it "should have a logger" do
    logger = Logger.new(File.dirname(__FILE__) + "/../../log/test.log")
    Coupler.logger = logger
    Coupler.logger.should == logger
  end
end
