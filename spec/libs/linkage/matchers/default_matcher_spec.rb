require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Linkage::Matchers::DefaultMatcher do
  before(:each) do
    @records = [
      [1, "123456789"],
      [2, "987654321"],
      [3, "123456789"],
      [4, "blah"],
      [5, "123456789"]
    ]

    @cache = stub(Linkage::Cache, :keys => (1..5).to_a, :count => 5)
    4.times do |i|
      @cache.stub!(:fetch).with(i+1).and_return(@records[i])
      @cache.stub!(:fetch).with(((i+2)..5).to_a).and_return(@records[(i+1)..5])
    end

    @matcher = create_matcher
  end

  def create_matcher(options = {})
    Linkage::Matchers::DefaultMatcher.new({
      'field'   => 'MomSSN',
      'formula' => '(!a.nil? && a == b) ? 100 : 0',
      'index'   => 1,
      'cache'   => @cache
    }.merge(options))
  end

  it "should have a field" do
    @matcher.field.should == 'MomSSN'
  end

  it "should fetch records from the cache for comparison" do
    4.times do |i|
      @cache.should_receive(:fetch).ordered.with(i+1).and_return(@records[i])
      @cache.should_receive(:fetch).ordered.with(((i+2)..5).to_a).and_return(@records[(i+1)..5])
    end
    @matcher.score
  end

  it "should score multiple values and return array of arrays of scores" do
    @matcher.score.should == [[0, 100, 0, 100], [0, 0, 0], [0, 100], [0]]
  end
end
