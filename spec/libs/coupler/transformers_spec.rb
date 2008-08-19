require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Transformers do
  before(:each) do
    Coupler::Transformers.reset
  end

  def create_xformer(options = {})
    options = {
      'formula' => 'x * 5',
      'default' => 'x',
      'type'    => 'integer',
      'name'    => 'pants'
    }.merge(options)

    Coupler::Transformers.create(options)
  end

  describe ".create" do
    before(:each) do
      @transformer = stub("default transformer")
      Coupler::Transformers::Default.stub!(:new).and_return(@transformer)
    end

    it "should create a default transformer" do
      Coupler::Transformers::Default.should_receive(:new).with({
        'formula' => 'x * 5',   'default' => 'x',
        'type'    => 'integer', 'name'    => 'pants'
      }).and_return(@transformer)
      create_xformer
    end

    it "should raise an error if a transformer with a duplicate name is created" do
      create_xformer
      lambda { create_xformer }.should raise_error
    end
  end

  describe ".reset" do
    it "should remove all transformers" do
      create_xformer('name' => 'shirt')
      Coupler::Transformers.reset
      lambda { create_xformer('name' => 'shirt') }.should_not raise_error
    end
  end
end
