require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Linkage::Matchers::ExactMatcher do
  before(:each) do
    @resource = stub(Linkage::Resource)
  end

  def create_matcher(options = {})
    Linkage::Matchers::ExactMatcher.new({
      'field'    => 'ssn',
      'index'    => 1,
      'resource' => @resource
    }.merge(options))
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

  it "should have custom scores" do
    m = create_matcher('scores' => [25, 75])
    m.true_score.should == 75
    m.false_score.should == 25
  end

  describe "#score" do
    before(:each) do
      @matcher = create_matcher
      @resource.stub!(:primary_key).and_return('id')
      @id_set = stub("id result set", :close => nil)
      @resource.stub!(:select).with(:columns => ['id'], :order => 'id').and_return(@id_set)
      @nil_set = stub("nil set", :close => nil, :next => nil)
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
        @id_set.stub!(:next).and_return([1], [2], [3], [4], [5], nil)
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000).and_return(@record_set)
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000, :offset => 1000).and_return(@nil_set)
      end

      it "should select ids in order from the resource" do
        @resource.should_receive(:select).with(:columns => ['id'], :order => 'id').and_return(@id_set)
        @matcher.score
      end

      it "should close the id set" do
        @id_set.should_receive(:close)
        @matcher.score
      end

      it "should close the record set" do
        @record_set.should_receive(:close)
        @matcher.score
      end

      it "should close the nil set" do
        @nil_set.should_receive(:close)
        @matcher.score
      end

      it "should select from resource, ordering by field" do
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000).and_return(@record_set)
        @matcher.score
      end

      it "should return an array of scores" do
        @matcher.score.should == [
          [0, 100, 0, 100],
          [0, 0, 0],
          [0, 100],
          [0]
        ]
      end

      it "should always score nils as non-matches" do
        @record_set.stub!(:next).and_return(
          [1, "123456789"],
          [3, "123456789"],
          [5, "123456789"],
          [4, nil],
          [2, nil],
          nil
        )
        @matcher.score.should == [
          [0, 100, 0, 100],
          [0, 0, 0],
          [0, 100],
          [0]
        ]
      end
    end

    describe "on 2000 records" do
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
        ids = (1..2000).collect { |i| [i] }
        @id_set.stub!(:next).and_return(*(ids + [nil]))
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000).and_return(@set1)
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000, :offset => 1000).and_return(@set2)
        @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000, :offset => 2000).and_return(@nil_set)
      end

      it "should select 1000 records at a time" do
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000).and_return(@set1)
        @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn', :limit => 1000, :offset => 1000).and_return(@set2)
        @matcher.score
      end

      it "should close all sets" do
        @set1.should_receive(:close)
        @set2.should_receive(:close)
        @nil_set.should_receive(:close)
        @matcher.score
      end
    end
  end
end
