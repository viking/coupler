require File.dirname(__FILE__) + "/../spec_helper.rb"

describe Linkage do
  it "should have a logger" do
    logger = Logger.new(File.dirname(__FILE__) + "/../../log/test.log")
    Linkage.logger = logger
    Linkage.logger.should == logger
  end
end
