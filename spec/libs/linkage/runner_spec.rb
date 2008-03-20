require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Runner do
  describe ".run" do
    before(:each) do
      @filename = File.expand_path(File.dirname(__FILE__) + "/../../fixtures/family.yml")
      @resource = stub(Linkage::Resource)
      @transformer = stub(Linkage::Transformer)
      Linkage::Resource.stub!(:new).and_return(@resource)
      Linkage::Transformer.stub!(:new).and_return(@transformer)
    end

    def do_run
      Linkage::Runner.run(@filename)
    end

    it "should accept a filename as an argument" do
      do_run
    end

    it "should create a new resource for each item in 'resources'" do
      Linkage::Resource.should_receive(:new).twice.and_return(@resource)
      do_run
    end

    it "should create a new transformer for each item in 'transformers'" do
      Linkage::Transformer.should_receive(:new).twice.and_return(@transformer)
      do_run
    end
  end
end
