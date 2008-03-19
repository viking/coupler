require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Runner do
  describe ".run" do
    before(:each) do
      @filename = File.expand_path(File.dirname(__FILE__) + "/../../fixtures/family.yml")
      @resource = stub(Linkage::Resource)
      Linkage::Resource.stub!(:new).and_return(@resource)
    end

    def do_run
      Linkage::Runner.run(@filename)
    end

    it "should accept a filename as an argument" do
      do_run
    end

    it "should create a new resource for each item in resources" do
      Linkage::Resource.should_receive(:new).twice.and_return(@resource)
      do_run
    end
  end
end
