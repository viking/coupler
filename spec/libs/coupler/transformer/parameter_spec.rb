require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformer::Parameter do
  it "should have a name" do
    p = Coupler::Transformer::Parameter.new('name' => 'x')
    p.name.should == 'x'
  end

  it "should have a coerce_to value" do
    p = Coupler::Transformer::Parameter.new('name' => 'x', 'coerce_to' => 'integer')
    p.coerce_to.should == 'integer'
  end

  it "should have a regexp" do
    p = Coupler::Transformer::Parameter.new({
      'name' => 'x',
      'coerce_to' => 'integer',
      'regexp' => '\d+'
    })
    p.regexp.should == /\d+/
  end

  describe "#valid?" do
    it "should return true if there are no conditions" do
      p = Coupler::Transformer::Parameter.new('name' => 'x')
      p.valid?(123).should be_true
    end

    it "should return true if there is a regexp and value matches" do
      p = Coupler::Transformer::Parameter.new({
        'name' => 'x',
        'regexp' => '\d+'
      })
      p.valid?(123).should be_true
    end
  end

  describe "#convert" do
    it "should return the value if no coercion needs to be done" do
      p = Coupler::Transformer::Parameter.new('name' => 'x')
      p.convert("blah").should == "blah"
    end

    it "should convert value to Fixnum if 'integer'" do
      p = Coupler::Transformer::Parameter.new('name' => 'x', 'coerce_to' => 'integer')
      p.convert("123").should == 123
    end

    it "should convert value to String if 'string'" do
      p = Coupler::Transformer::Parameter.new('name' => 'x', 'coerce_to' => 'string')
      p.convert(123).should == "123"
    end

    it "should not convert a nil to anything" do
      p = Coupler::Transformer::Parameter.new('name' => 'x', 'coerce_to' => 'string')
      p.convert(nil).should == nil
    end
  end
end

