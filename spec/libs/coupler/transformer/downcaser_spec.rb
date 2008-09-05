require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformer::Downcaser do
  Downcaser = Coupler::Transformer::Downcaser

  def create_downcaser
    options = {
      'field' => 'blargh',
      'arguments' => {
        'from' => 'bar',
      }
    }.merge(options)
    Downcaser.new(options)
  end

  it "should be a subclass of Base" do
    Downcaser.superclass.should == Coupler::Transformer::Base
  end

  it "should have one parameter" do
    Downcaser.should have(1).parameters
  end

  it "should have a parameter named 'from'" do
    Downcaser.parameters[0].should == "from"
  end

  it "should have a sql_template" do
    Downcaser.sql_template.should == "LOWER(from)"
  end

  it "should have a ruby template" do
    Downcaser.ruby_template.should == "from.downcase"
  end

  it "should have a type template" do
    Downcaser.type_template.should == "same as from"
  end
end
