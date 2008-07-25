require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Matchers::ExactMatcher do
  before(:each) do
    @resource = stub(Coupler::Resource)
    @options  = Coupler::Options.new
  end

  def create_matcher(spec = {}, opts = {})
    Coupler::Matchers::ExactMatcher.new({
      'fields'   => %w{ssn},
      'type'     => 'exact',
      'resource' => @resource
    }.merge(spec), @options)
  end

  it "should handle multiple resources"

  it "should have a default true_score" do
    m = create_matcher
    m.true_score.should == 100
  end

  it "should have a default false_score" do
    m = create_matcher
    m.false_score.should == 0
  end

  it "should have custom true/false scores" do
    m = create_matcher('scores' => [25, 75])
    m.true_score.should == 75
    m.false_score.should == 25
  end

  it "should have multiple fields" do
    m = Coupler::Matchers::ExactMatcher.new({
      'fields'   => %w{ssn dob}, 
      'type'     => 'exact',
      'resource' => @resource
    }, @options)
    m.fields.should == %w{ssn dob}
  end

  it "should have one field" do
    m = Coupler::Matchers::ExactMatcher.new({
      'field'    => 'ssn', 
      'type'     => 'exact',
      'resource' => @resource
    }, @options)
    m.fields.should == %w{ssn}
  end

  describe "#score" do
    before(:each) do
      @matcher  = create_matcher
      @recorder = stub(Coupler::Scores::Recorder, :add => nil)
      @nil_set  = stub("nil set", :close => nil, :next => nil)
      @resource.stub!(:primary_key).and_return('id')
    end

    describe "on 5 records" do
      before(:each) do
        @record_set = stub("record result set", :close => nil)
        @record_set.stub!(:next).and_return(
          [1, "123456789"],
          [3, "123456789"],
          [5, "123456789"],
          [4, "423156789"],
          [2, "bippityboppity"],
          nil
        )
      end

      describe "on one field" do
        before(:each) do
          @resource.stub!(:select).with({
            :columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000,
            :conditions => an_instance_of(String)
          }).and_return(@record_set)
          @resource.stub!(:select).with({
            :columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000, :offset => 10000,
            :conditions => an_instance_of(String)
          }).and_return(@nil_set)
        end

        it "should close the record set" do
          @record_set.should_receive(:close)
          @matcher.score(@recorder)
        end

        it "should close the nil set" do
          @nil_set.should_receive(:close)
          @matcher.score(@recorder)
        end

        it "should select from resource, ordering by field and avoiding nulls" do
          @resource.should_receive(:select).with({
            :columns => ['id', 'ssn'], 
            :order => 'ssn',
            :limit => 10000,
            :conditions => "WHERE ssn IS NOT NULL"
          }).and_return(@record_set)
          @matcher.score(@recorder)
        end

        it "should add matches to the recorder" do
          @recorder.should_receive(:add).with(3, 1, 100)
          @recorder.should_receive(:add).with(5, 1, 100)
          @recorder.should_receive(:add).with(5, 3, 100)
          @matcher.score(@recorder)
        end
      end

      describe "on multiple fields" do
        before(:each) do
          @matcher = create_matcher('fields' => %w{ssn dob})
          @record_set.stub!(:next).and_return(
            [1, "123456789", "1969-01-01"],
            [3, "123456789", "1969-01-01"],
            [5, "123456789", "1969-01-01"],
            [6, "123456789", "1975-01-01"],
            [4, "423156789", "2000-01-01"],
            [2, "bippityboppity", "2002-01-01"],
            nil
          )
          @resource.stub!(:select).with({
            :columns => ['id', 'ssn', 'dob'], :order => 'ssn, dob', :limit => 10000,
            :conditions => an_instance_of(String)
          }).and_return(@record_set)
          @resource.stub!(:select).with({
            :columns => ['id', 'ssn', 'dob'], :order => 'ssn, dob',
            :limit => 10000, :offset => 10000,
            :conditions => an_instance_of(String)
          }).and_return(@nil_set)
        end

        it "should select from resource, ordering by all fields" do
          @resource.should_receive(:select).with({
            :columns => ['id', 'ssn', 'dob'], :order => 'ssn, dob', :limit => 10000,
            :conditions => "WHERE ssn IS NOT NULL AND dob IS NOT NULL"
          }).and_return(@record_set)
          @matcher.score(@recorder)
        end

        it "should add matches to the recorder" do
          @recorder.should_receive(:add).with(3, 1, 100)
          @recorder.should_receive(:add).with(5, 1, 100)
          @recorder.should_receive(:add).with(5, 3, 100)
          @recorder.should_not_receive(:add).with(6, anything(), anything())
          @matcher.score(@recorder)
        end
      end
    end

    describe "on a lot of records" do
      before(:each) do
        @sets = []
        @sets[0] = stub("first result set", :close => nil)
        @sets[0].stub!(:next).and_return(
          [1, "123456789"],
          [3, "123456789"],
          nil
        )
        @sets[1] = stub("second result set", :close => nil)
        @sets[1].stub!(:next).and_return(
          [5, "123456789"],
          [4, "423156789"],
          [2, "bippityboppity"],
          nil
        )
        @sets[2] = @nil_set

        @opts = { 
          :columns => ['id', 'ssn'], :order => 'ssn',
          :limit => 10000, :conditions => "WHERE ssn IS NOT NULL" 
        }
        3.times do |i|
          offset = 10000 * i
          @resource.stub!(:select).with(
            offset > 0 ? @opts.merge(:offset => offset) : @opts
          ).and_return(@sets[i])
        end
      end

      it "should select 10000 records at a time" do
        3.times do |i|
          offset = 10000 * i
          @resource.should_receive(:select).with(
            offset > 0 ? @opts.merge(:offset => offset) : @opts
          ).and_return(@sets[i])
        end
        @matcher.score(@recorder)
      end

      it "should select 50000 records at a time when --db-limit is 50000" do
        @options.db_limit = 50000
        @opts[:limit]     = 50000

        m = create_matcher
        3.times do |i|
          offset = 50000 * i
          @resource.should_receive(:select).with(
            offset > 0 ? @opts.merge(:offset => offset) : @opts
          ).and_return(@sets[i])
        end
        m.score(@recorder)
      end

      it "should close all sets" do
        @sets.each { |s| s.should_receive(:close) }
        @matcher.score(@recorder)
      end
    end
  end
end
