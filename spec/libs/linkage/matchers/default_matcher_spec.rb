require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Linkage::Matchers::DefaultMatcher do
  def create_matcher(options = {})
    Linkage::Matchers::DefaultMatcher.new({
      'field'   => 'MomSSN',
      'formula' => '(!a.nil? && a == b) ? 100 : 0',
      'index'   => 1,
      'cache'   => @cache
    }.merge(options))
  end

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

    @matcher  = create_matcher
    @recorder = stub(Linkage::Scores::Recorder, :add => nil)
  end

  it "should have a field" do
    @matcher.field.should == 'MomSSN'
  end

  it "should fetch records from the cache for comparison" do
    4.times do |i|
      @cache.should_receive(:fetch).ordered.with(i+1).and_return(@records[i])
      @cache.should_receive(:fetch).ordered.with(((i+2)..5).to_a).and_return(@records[(i+1)..5])
    end
    @matcher.score(@recorder)
  end

  it "should add scores to the recorder" do
    @recorder.should_receive(:add).with(1, 2, 0)
    @recorder.should_receive(:add).with(1, 3, 100)
    @recorder.should_receive(:add).with(1, 4, 0)
    @recorder.should_receive(:add).with(1, 5, 100)
    @recorder.should_receive(:add).with(2, 3, 0)
    @recorder.should_receive(:add).with(2, 4, 0)
    @recorder.should_receive(:add).with(2, 5, 0)
    @recorder.should_receive(:add).with(3, 4, 0)
    @recorder.should_receive(:add).with(3, 5, 100)
    @recorder.should_receive(:add).with(4, 5, 0)
    @matcher.score(@recorder)
  end
end
