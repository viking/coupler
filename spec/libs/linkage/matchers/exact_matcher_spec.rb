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
      @record_set = stub("record result set", :close => nil)
      @record_set.stub!(:next).and_return(
        [1, "123456789"],
        [3, "123456789"],
        [5, "123456789"],
        [4, "423156789"],
        [2, "bippityboppity"],
        nil
      )
      @id_set = stub("id result set", :close => nil)
      @id_set.stub!(:next).and_return([1], [2], [3], [4], [5], nil)
      @resource.stub!(:select).with(:columns => ['id'], :order => 'id').and_return(@id_set)
      @resource.stub!(:select).with(:columns => ['id', 'ssn'], :order => 'ssn').and_return(@record_set)
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

    it "should select from resource, ordering by field" do
      @resource.should_receive(:select).with(:columns => ['id', 'ssn'], :order => 'ssn').and_return(@record_set)
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
  end
end
