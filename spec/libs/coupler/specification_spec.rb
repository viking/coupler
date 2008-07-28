require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Specification do
  before(:each) do
    @filename = File.dirname(__FILE__) + "/../../fixtures/sauce.yml"
    @raw_spec = YAML.load_file(@filename)
  end

  def do_parse
    Coupler::Specification.parse(@filename)
  end

  it "should load the file and return a hash" do
    do_parse.should == @raw_spec 
  end

  it "should pass a templated file through Erubis first" do
    @filename << ".erb"
    do_parse.should == @raw_spec 
  end
end
