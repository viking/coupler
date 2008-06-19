require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Matchers::ExactMatcher do
  before(:each) do
    @resource = stub(Coupler::Resource)
    @options  = Coupler::Options.new
  end

  def create_matcher(spec = {}, opts = {})
    Coupler::Matchers::ExactMatcher.new({
      'field'    => 'ssn',
      'type'     => 'exact',
      'resource' => @resource
    }.merge(spec), @options)
  end

  it "should have a field" do
    m = create_matcher
    m.field.should == 'ssn'
  end

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
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000).and_return(@record_set)
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000, :offset => 10000).and_return(@nil_set)
      end

      it "should close the record set" do
        @record_set.should_receive(:close)
        @matcher.score(@recorder)
      end

      it "should close the nil set" do
        @nil_set.should_receive(:close)
        @matcher.score(@recorder)
      end

      it "should select from resource, ordering by field" do
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000).and_return(@record_set)
        @matcher.score(@recorder)
      end

      it "should add matches to the recorder" do
        @recorder.should_receive(:add).with(3, 1, 100)
        @recorder.should_receive(:add).with(5, 1, 100)
        @recorder.should_receive(:add).with(5, 3, 100)
        @matcher.score(@recorder)
      end

      it "should consider nils as non-matches" do
        @record_set.stub!(:next).and_return(
          [1, "123456789"],
          [3, "123456789"],
          [5, "123456789"],
          [4, nil],
          [2, nil],
          nil
        )
        @recorder.should_not_receive(:add).with(2, 4, 100)
        @recorder.should_not_receive(:add).with(4, 2, 100)
        @matcher.score(@recorder)
      end
    end

    describe "on a lot of records" do
      before(:each) do
        @set1 = stub("first result set", :close => nil)
        @set1.stub!(:next).and_return(
          [1, "123456789"],
          [3, "123456789"],
          nil
        )
        @set2 = stub("second result set", :close => nil)
        @set2.stub!(:next).and_return(
          [5, "123456789"],
          [4, "423156789"],
          [2, "bippityboppity"],
          nil
        )
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000).and_return(@set1)
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000, :offset => 10000).and_return(@set2)
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000, :offset => 20000).and_return(@nil_set)
      end

      it "should select 10000 records at a time" do
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000).and_return(@set1)
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000, :offset => 10000).and_return(@set2)
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 10000, :offset => 20000).and_return(@nil_set)
        @matcher.score(@recorder)
      end

      it "should select 50000 records at a time when --db-limit is 50000" do
        @options.db_limit = 50000
        m = create_matcher
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 50000).and_return(@set1)
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 50000, :offset => 50000).and_return(@set2)
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 50000, :offset => 100000).and_return(@nil_set)
        m.score(@recorder)
      end

      it "should close all sets" do
        @set1.should_receive(:close)
        @set2.should_receive(:close)
        @nil_set.should_receive(:close)
        @matcher.score(@recorder)
      end
    end
  end
end
