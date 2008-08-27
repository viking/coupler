require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformer::Trimmer do
  Trimmer = Coupler::Transformer::Trimmer

  def create_trimmer
    options = {
      'field' => 'blargh',
      'arguments' => {
        'from' => 'bar',
      }
    }.merge(options)
    Trimmer.new(options)
  end

  it "should be a subclass of Base" do
    Trimmer.superclass.should == Coupler::Transformer::Base
  end

  it "should have one parameter" do
    Trimmer.should have(1).parameters
  end

  it "should have a parameter named 'from'" do
    Trimmer.parameters[0].should == "from"
  end

  it "should have a sql_template" do
    Trimmer.sql_template.should == "TRIM(from)"
  end

  it "should have a ruby template" do
    Trimmer.ruby_template.should == "from.strip"
  end

  it "should have a type template" do
    Trimmer.type_template.should == "same as from"
  end
end
