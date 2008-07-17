require File.dirname(__FILE__) + "/../spec_helper.rb"

describe Buffer do
  before(:each) do
    @buffer = Buffer.new(10)
  end

  it "should have a length of 0" do
    @buffer.length.should == 0
  end

  it "should be empty" do
    @buffer.should be_empty
  end

  it "should not be empty after adding an item" do
    @buffer << 1
    @buffer.should_not be_empty
  end

  describe "#<<" do
    it "should add an entry to the buffer" do
      @buffer << "foo"
      @buffer.length.should == 1
    end

    it "should return itself" do
      (@buffer << "foo").should == @buffer
    end

    it "should raise an exception if full" do
      10.times { |i| @buffer << i }
      lambda { @buffer << 10 }.should raise_error
    end
  end

  describe "#each" do
    before(:each) do
      (1..5).each { |i| @buffer << i }
    end

    it "should yield each element in the buffer" do
      expected = (1..5).to_a
      @buffer.each { |i| expected.delete(i) }
      expected.should == []
    end
  end

  describe "#full?" do
    it "should be false by default" do
      @buffer.should_not be_full
    end

    it "should be true if 10 elements have been added" do
      10.times { |i| @buffer << i }
      @buffer.should be_full
    end
  end

  describe "#flush!" do
    it "should set the buffer's length to 0" do
      @buffer.flush!
      @buffer.length.should == 0
    end
  end
  
  describe "#data" do
    it "should return a subarray" do
      @buffer << 123 << 456
      @buffer.data.should == [123, 456]
    end
  end

  it "should be enumerable" do
    Buffer.included_modules.should include(Enumerable)
  end
end
