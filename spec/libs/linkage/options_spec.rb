require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Options do
  describe ".parse" do

    def do_parse(args = %w{foo.yml bar.yml --use-existing-scratch})
      @options = Linkage::Options.parse(args)
    end

    it "should return an Options object" do
      do_parse
      @options.should be_an_instance_of(Linkage::Options)
    end

    it "should have filenames" do
      do_parse
      @options.filenames.should == %w{foo.yml bar.yml}
    end

    it "should set use_existing_scratch" do
      do_parse
      @options.use_existing_scratch.should be_true
    end
  end

  it "should not use_existing_scratch by default" do
    opts = Linkage::Options.new
    opts.use_existing_scratch.should be_false
  end

  it "should have no filenames by default" do
    opts = Linkage::Options.new
    opts.filenames.should == []
  end
end
