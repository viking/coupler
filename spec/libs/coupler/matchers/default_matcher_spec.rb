require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Matchers::DefaultMatcher do
  before(:each) do
    @options = Coupler::Options.new
    @caches = [
      stub("cache one", :keys => (1..5).to_a,  :count => 5),
      stub("cache two", :keys => (6..10).to_a, :count => 5)
    ]
  end

  def create_matcher(spec = {})
    Coupler::Matchers::DefaultMatcher.new({
      'field'   => 'MomSSN',
      'formula' => '(!a.nil? && a == b) ? 100 : 0',
      'index'   => 1,
      'caches'  => @caches
    }.merge(spec), @options)
  end

  it "should not be so damn slow"

  it "should have a field" do
    create_matcher.field.should == 'MomSSN'
  end

  describe "in self-join mode" do
    before(:each) do
      @caches.pop
      @records = [
        [1, "123456789"],
        [2, "987654321"],
        [3, "123456789"],
        [4, "blah"],
        [5, "123456789"]
      ]
      4.times do |i|
        @caches[0].stub!(:fetch).with(i+1).and_return(@records[i])
        @caches[0].stub!(:fetch).with(((i+2)..5).to_a).and_return(@records[(i+1)..5])
      end
      @matcher  = create_matcher
      @recorder = stub(Coupler::Scores::Recorder, :add => nil)
    end

    it "should fetch records from the cache for comparison" do
      4.times do |i|
        @caches[0].should_receive(:fetch).ordered.with(i+1).and_return(@records[i])
        @caches[0].should_receive(:fetch).ordered.with(((i+2)..5).to_a).and_return(@records[(i+1)..5])
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

  describe "in dual-join mode" do
    before(:each) do
      @set1 = [
        [1, "apple"], [2, "orange"], 
        [3, "apple"], [4, "potato"], [5, "kiwi"]
      ]
      @set2 = [
        [6, "potato"], [7, "pineapple"],
        [8, "potato"], [9, "black-eyed pea"], [10, "apple"]
      ]
      (1..5).each { |i| @caches[0].stub!(:fetch).with(i).and_return(@set1[i-1]) }
      @caches[1].stub!(:fetch).and_return(@set2)

      @matcher  = create_matcher
      @recorder = stub(Coupler::Scores::Recorder, :add => nil)
    end

    it "should fetch records from the caches for comparison" do
      (1..5).each do |i|
        @caches[0].should_receive(:fetch).with(i).and_return(@set1[i-1])
      end
      @caches[1].should_receive(:fetch).with([6,7,8,9,10]).and_return(@set2)
      @matcher.score(@recorder)
    end

    it "should add scores to the recorder" do
      @set1.each do |(id1, v1)|
        @set2.each do |(id2, v2)|
          @recorder.should_receive(:add).with(id1, id2, v1 == v2 ? 100 : 0)
        end
      end
      @matcher.score(@recorder)
    end
  end
end
