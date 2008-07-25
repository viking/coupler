require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Specification do
  before(:each) do
    @filename = File.dirname(__FILE__) + "/../../fixtures/sauce.yml"
    @raw_spec = YAML.load_file(@filename)
  end

  def create_spec
    Coupler::Specification.new(@filename)
  end

  it "should load the file" do
    create_spec
  end

  it "should have resources" do
    create_spec.resources.should == @raw_spec['resources']
  end

  it "should have transformations" do
    create_spec.transformations.should == @raw_spec['transformations']
  end

  it "should have scenarios" do
    create_spec.scenarios.should == @raw_spec['scenarios']
  end

  it "should pass a templated file through Erubis first" do
    @filename << ".erb"
    s = create_spec
    s.resources.should == @raw_spec['resources']
    s.transformations.should == @raw_spec['transformations']
    s.scenarios.should == @raw_spec['scenarios']
  end
end
