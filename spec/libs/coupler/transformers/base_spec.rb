require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformers::Base do
  before(:each) do
    Coupler::Transformers.reset
  end

  def create_xformer(options = {})
    options = {
      'formula' => 'x * 5',
      'default' => 'x',
      'type'    => 'integer',
      'name'    => 'optimus_prime'
    }.merge(options)
    Coupler::Transformers::Base.new(options)
  end

  it "should have a name" do
    create_xformer.name.should == "optimus_prime" 
  end

  it "should raise an error if a transformer has a duplicate name" do
    xf = create_xformer
    lambda { create_xformer }.should raise_error
  end

  describe "#transform" do
    it "should raise a NotImplementedError" do
      lambda { create_xformer.transform }.should raise_error(NotImplementedError)
    end
  end
end
