require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Matcher::Master do
  before(:each) do
    @options   = Coupler::Options.new
    @exact     = stub("exact matcher", :field => 'bar', :score => nil, :false_score => 0)
    @default   = stub("default matcher", :field => 'foo', :score => nil)
    @scores    = stub(Coupler::Scores)
    @recorder  = stub(Coupler::Scores::Recorder)
    @scores_db = stub(Coupler::Resource, :drop_table => nil, :create_table => nil)
    Coupler::Resource.stub!(:find).with('scores').and_return(@scores_db)
    @scores.stub!(:record).and_yield(@recorder)

    @scratches = [
      stub("birth scratch resource", :name => 'birth', :keys => [1,2,3,4,5]),
      stub("death scratch resource", :name => 'death', :keys => [6,7,8]),
    ]
    @parent = stub("parent scenario", {
      :name => "foo", :scratches => @scratches,
      :field_list => %w{id foo bar}, :range => 40..100,
      :combining_method => 'mean'
    })
    @caches = {
      :birth => stub("birth cache", :auto_fill! => nil),
      :death => stub("death cache", :auto_fill! => nil)
    }
    @caches.each_pair do |name, obj|
      Coupler::CachedResource.stub!(:new).with(name.to_s, @options).and_return(obj)
    end

    Coupler::Matcher::Exact.stub!(:new).and_return(@exact)
    Coupler::Matcher::Default.stub!(:new).and_return(@default)
    Coupler::Scores.stub!(:new).and_return(@scores)
  end

  def create_master
    Coupler::Matcher::Master.new(@parent, @options)
  end

  def create_master_with_matchers(options = {})
    m = create_master
    m.add_matcher({'field' => 'bar', 'type' => 'exact'})
    m.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
    m
  end

  it "should have a field_list" do
    m = create_master
    m.field_list.should == %w{id foo bar}
  end

  it "should find the scores resource" do
    Coupler::Resource.should_receive(:find).with('scores').and_return(@scores_db)
    create_master
  end

  it "should have no matchers" do
    m = create_master
    m.matchers.should be_empty
  end

  it "should have a combining_method" do
    m = create_master
    m.combining_method.should == "mean"
  end

  it "should have a range" do
    m = create_master
    m.range.should == (40..100)
  end

  it "should create caches for each resource" do
    @caches.each_pair do |name, obj|
      Coupler::CachedResource.should_receive(:new).with(name.to_s, @options).and_return(obj)
    end
    create_master
  end

  describe "#add_matcher" do
    before(:each) do
      @master = create_master
    end

    it "should create an exact matcher" do
      Coupler::Matcher::Exact.should_receive(:new).with({
        'field' => 'bar', 'type' => 'exact',
        'resources' => @scratches
      }, @options).and_return(@exact)
      @master.add_matcher({'field' => 'bar', 'type' => 'exact'})
    end

    it "should create a default matcher" do
      Coupler::Matcher::Default.should_receive(:new).with({
        'field' => 'foo', 'formula' => 'a > b ? 100 : 0', 'index' => 1,
        'caches' => @caches.values_at(:birth, :death)
      }, @options).and_return(@default)
      @master.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
    end

    it "should auto_fill! the caches only when adding the first default matcher" do
      @caches.values.each { |c| c.should_receive(:auto_fill!) }
      @master.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
      @caches.values.each { |c| c.should_not_receive(:auto_fill!) }
      @master.add_matcher({'field' => 'bar', 'formula' => 'a > b ? 100 : 0'})
    end
  end

  describe "#score" do
    before(:each) do
      @master = create_master_with_matchers
    end

    it "should create a scores object" do
      Coupler::Scores.should_receive(:new).with({
        'combining method' => "mean",
        'range'    => 40..100,
        'num'      => 2,
        'keys'     => [[1,2,3,4,5], [6,7,8]],
        'defaults' => [0, 0],
        'resource' => @scores_db,
        'name'     => 'foo'
      }, @options).and_return(@scores)
      @master.score
    end

    it "should call score for each matcher" do
      @exact.should_receive(:score).with(@recorder)
      @default.should_receive(:score).with(@recorder)
      @master.score
    end

    it "should return a scores object" do
      @master.score.should == @scores
    end
  end
end
