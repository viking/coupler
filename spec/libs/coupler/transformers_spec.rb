require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Transformers do
  def create_xformer(options = {})
    options = {
      'formula' => 'x * 5',
      'default' => 'x',
      'type'    => 'integer',
      'name'    => 'pants'
    }.merge(options)

    Coupler::Transformers::DefaultTransformer.new(options)
  end

  describe ".find" do
    it "should find a previously created transformer by name" do
      xf = create_xformer('name' => 'pants')
      Coupler::Transformers.find(xf.name).should == xf
    end
  end

  describe ".reset" do
    it "should remove all transformers" do
      xf1 = create_xformer('name' => 'shirt')
      xf2 = create_xformer('name' => 'jeans')
      Coupler::Transformers.reset
      Coupler::Transformers.find(xf1.name).should be_nil
      Coupler::Transformers.find(xf2.name).should be_nil
    end
  end
end
