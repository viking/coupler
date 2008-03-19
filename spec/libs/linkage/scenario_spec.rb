require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Scenario do

  describe 'when self-joining' do
    before(:each) do
      @opts = { 
        'name'   => 'family', 
        'type'   => 'self-join',
      }
      @resource = mock(Linkage::Resource)
      @scenario = Linkage::Scenario.new(@opts, @resource)
    end

    it "should have a name" do
      @scenario.name.should == 'family'
    end

    it "should have a type of self-join" do
      @scenario.type.should == 'self-join'
    end

    it "should have 1 resource" do
      @scenario.should have(1).resources
    end
  end
end
