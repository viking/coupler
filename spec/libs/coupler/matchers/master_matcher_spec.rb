require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Matchers::MasterMatcher do
  before(:each) do
    @options   = Coupler::Options.new
    @exact     = stub("exact matcher", :field => 'bar', :score => nil, :false_score => 0)
    @default   = stub("default matcher", :field => 'foo', :score => nil)
    @scratch   = stub(Coupler::Resource, :keys => [1,2,3,4])
    @scores_db = stub(Coupler::Resource, :drop_table => nil, :create_table => nil)
    @scores    = stub(Coupler::Scores)
    @recorder  = stub(Coupler::Scores::Recorder)
    @scores.stub!(:record).and_yield(@recorder)

    @resources = [
      stub("birth resource", :name => 'birth'),
      stub("death resource", :name => 'death'),
    ]
    @parent = stub("parent scenario", :name => "foo", :resources => @resources)
    @caches = {
      :birth => stub("birth cache"),
      :death => stub("death cache")
    }
    @caches.each_pair do |name, obj|
      Coupler::Cache.stub!(:new).with(name.to_s, @options).and_return(obj)
    end

    Coupler::Matchers::ExactMatcher.stub!(:new).and_return(@exact)
    Coupler::Matchers::DefaultMatcher.stub!(:new).and_return(@default)
    Coupler::Scores.stub!(:new).and_return(@scores)
  end

  def create_master(spec = {}, opts = {})
    Coupler::Matchers::MasterMatcher.new({
      'field list' => %w{id foo bar},
      'combining method' => "mean",
      'range'    => 40..100,
      'scratch'  => @scratch,
      'scores'   => @scores_db,
      'parent'   => @parent
    }.merge(spec), @options)
  end

  def create_master_with_matchers(options = {})
    m = create_master(options)
    m.add_matcher({'field' => 'bar', 'type' => 'exact'})
    m.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
    m
  end

  it "should have a field_list" do
    m = create_master
    m.field_list.should == %w{id foo bar}
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
      Coupler::Cache.should_receive(:new).with(name.to_s, @options).and_return(obj)
    end
    create_master
  end

  describe "#add_matcher" do
    before(:each) do
      @master = create_master
    end

    it "should create an exact matcher" do
      Coupler::Matchers::ExactMatcher.should_receive(:new).with({
        'field' => 'bar', 'type' => 'exact',
        'resources' => @resources, 'scratch' => @scratch
      }, @options).and_return(@exact)
      @master.add_matcher({'field' => 'bar', 'type' => 'exact'})
    end

    it "should create a default matcher" do
      Coupler::Matchers::DefaultMatcher.should_receive(:new).with({
        'field' => 'foo', 'formula' => 'a > b ? 100 : 0', 'index' => 1,
        'cache' => @cache
      }, @options).and_return(@default)
      @master.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
    end
  end

  describe "#score" do
    before(:each) do
      @master = create_master_with_matchers
    end

    it "should create a scores object" do
      Coupler::Scores.should_receive(:new).with({
        'combining method' => "mean",
        'range' => 40..100,
        'keys'  => [1, 2, 3, 4],
        'num'   => 2,
        'defaults' => [0, 0],
        'resource' => @scores_db,
        'name' => 'foo'
      }, @options).and_return(@scores)
      @master.score
    end

    it "should get keys from the resource" do
      @scratch.should_receive(:keys).and_return([1,2,3,4])
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
