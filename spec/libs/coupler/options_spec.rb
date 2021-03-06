require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Options do
  describe ".parse" do

    def do_parse(args = %w{foo.yml})
      @options = Coupler::Options.parse(args)
    end

    it "should return an Options object" do
      do_parse
      @options.should be_an_instance_of(Coupler::Options)
    end

    it "should have a filename" do
      do_parse
      @options.filename.should == "foo.yml"
    end

    it "should set csv_output" do
      do_parse %w{foo.yml --csv}
      @options.csv_output.should be_true
    end

    it "should set db_limit" do
      do_parse %w{foo.yml --db-limit=50000}
      @options.db_limit.should == 50000
    end

    it "should set log_level to DEBUG" do
      do_parse %w{foo.yml -v}
      @options.log_level.should == Logger::DEBUG
    end

    it "should set log_file to foo.log" do
      do_parse %w{foo.yml -f foo.log}
      @options.log_file.should == "foo.log"
    end

    it "should set guaranteed" do
      do_parse %w{foo.yml -g 10000}
      @options.guaranteed.should == 10000
    end
  end

  describe "default settings" do
    before(:each) do
      @opts = Coupler::Options.new
    end

    it "should not output csv's" do
      @opts.csv_output.should be_false
    end

    it "should have no filename" do
      @opts.filename.should == nil
    end

    it "should have a db limit of 10000" do
      @opts.db_limit.should == 10000
    end

    it "should have a log level of info" do
      @opts.log_level.should == Logger::INFO
    end

    it "should have a log_file of log/runner.log" do
      @opts.log_file.should == File.expand_path("log/runner.log")
    end

    it "should have a guaranteed of 0" do
      @opts.guaranteed.should == 0
    end

    it "should have a nil specification" do
      @opts.specification.should == nil
    end
  end
end
