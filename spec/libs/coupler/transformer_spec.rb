require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Transformer do
  describe ".[]" do
    it "should return a class" do
      Coupler::Transformer["trimmer"].should == Coupler::Transformer::Trimmer
    end

    it "should find all built-in transformer classes" do
      Coupler::Transformer["trimmer"].should == Coupler::Transformer::Trimmer
      Coupler::Transformer["renamer"].should == Coupler::Transformer::Renamer
      Coupler::Transformer["downcaser"].should == Coupler::Transformer::Downcaser
    end
  end

  describe ".build" do
    before(:each) do
      @klass = stub("custom transformer class")
      Coupler::Transformer::Custom.stub!(:build).and_return(@klass)
    end

    def do_build(opts = {})
      options = {
        'name' => 'bar_bender',
        'parameters' => %w{fry leela},
        'ruby' => "fry < 10 ? leela * 10 : fry / 5",
        'sql'  => "IF(fry < 10, leela * 10, fry / 5)",
        'type' => 'int',
      }.merge(opts)
      Coupler::Transformer.build(options)
    end

    it "should call Custom.build" do
      Coupler::Transformer::Custom.should_receive(:build).and_return(@klass)
      do_build
    end

    it "should make a class that's accessible by []" do
      do_build
      Coupler::Transformer["bar_bender"].should == @klass
    end
  end
end
