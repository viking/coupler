require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformer::Renamer do
  Renamer = Coupler::Transformer::Renamer

  it "should be a subclass of Base" do
    Renamer.superclass.should == Coupler::Transformer::Base
  end

  it "should have one parameter" do
    Renamer.should have(1).parameters
  end

  it "should have a parameter named 'from'" do
    Renamer.parameters[0].should == "from"
  end

  it "should have a sql_template" do
    Renamer.sql_template.should == "from"
  end

  it "should have a ruby template" do
    Renamer.ruby_template.should == "from"
  end

  it "should have a type template" do
    Renamer.type_template.should == "same as from"
  end
end
