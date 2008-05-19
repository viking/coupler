require File.dirname(__FILE__) + "/../../../spec_helper.rb"

shared_examples_for "any combining method" do
  it "should call score for each matcher" do
    @exact.should_receive(:score).and_return([[80, 60, 0], [30, 70], [25]])
    @default.should_receive(:score).and_return([[0, 100, 0], [100, 0], [100]])
    @master.score
  end

  it "should grab keys from the cache" do
    @cache.should_receive(:keys).and_return([1, 2, 3, 4])
    @master.score
  end
end

describe Linkage::Matchers::MasterMatcher do
  before(:each) do
    @exact    = stub("exact matcher", :field => 'bar')
    @default  = stub("default matcher", :field => 'foo')
    @cache    = stub(Linkage::Cache)
    @resource = stub(Linkage::Resource)
    Linkage::Matchers::ExactMatcher.stub!(:new).and_return(@exact)
    Linkage::Matchers::DefaultMatcher.stub!(:new).and_return(@default)
  end

  def create_master(options = {})
    Linkage::Matchers::MasterMatcher.new({
      'field list' => %w{id foo bar},
      'combining method' => "mean",
      'groups' => {
        'good'  => 40..75,
        'great' => 75..90,
        'leet'  => 91..100
      },
      'cache'    => @cache,
      'resource' => @resource
    }.merge(options))
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

  it "should have groups" do
    m = create_master
    m.groups.should == {
      'good'  => 40..75,
      'great' => 75..90,
      'leet'  => 91..100
    }
  end

  describe "#add_matcher" do
    before(:each) do
      @master = create_master
    end

    it "should create an exact matcher" do
      Linkage::Matchers::ExactMatcher.should_receive(:new).with({
        'field' => 'bar', 'type' => 'exact', 'index' => 2,
        'resource' => @resource
      }).and_return(@exact)
      @master.add_matcher({'field' => 'bar', 'type' => 'exact'})
    end

    it "should create an default matcher" do
      Linkage::Matchers::DefaultMatcher.should_receive(:new).with({
        'field' => 'foo', 'formula' => 'a > b ? 100 : 0', 'index' => 1,
        'cache' => @cache
      }).and_return(@default)
      @master.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
    end
  end

  describe "#score" do
    before(:each) do
      @exact.stub!(:score).with.and_return([[80, 60, 0], [30, 70], [25]])
      @default.stub!(:score).with.and_return([[0, 100, 0], [100, 0], [100]])
      @cache.stub!(:keys).and_return([1, 2, 3, 4])
    end

    describe "when using the mean combining method" do
      before(:each) do
        @master = create_master_with_matchers
      end

      it_should_behave_like "any combining method"

      it "should return a hash of group arrays" do
        @master.score.should == {
          'good'  => [[1, 2, 40], [2, 3, 65], [3, 4, 62]],
          'great' => [[1, 3, 80]]
        }
      end
    end

    describe "when using the sum combining method" do
      before(:each) do
        @master = create_master_with_matchers({
          'combining method' => 'sum',
          'groups' => {
            'good'  =>  80..150,
            'great' => 151..180,
            'leet'  => 181..200
          }
        })
      end

      it_should_behave_like "any combining method"

      it "should return an array of sums" do
        @master.score.should == {
          'good'  => [[1, 2, 80], [2, 3, 130], [3, 4, 125]],
          'great' => [[1, 3, 160]]
        }
      end
    end
  end
end
