require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Linkage::Matchers::MasterMatcher do
  def create_master(options = {})
    Linkage::Matchers::MasterMatcher.new({
      'field list' => %w{id foo bar},
      'combining method' => "mean",
      'groups' => {
        'good'  => 40..75,
        'great' => 75..90,
        'leet'  => 91..100
      }
    }.merge(options))
  end

  def create_master_with_matchers(options = {})
    m = create_master(options)
    m.add_matcher({'field' => 'bar', 'type' => 'exact'})
    m.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
    m
  end

  before(:each) do
    @exact   = stub("exact matcher", :field => 'bar')
    @default = stub("default matcher", :field => 'foo')
    Linkage::Matchers::ExactMatcher.stub!(:new).and_return(@exact)
    Linkage::Matchers::DefaultMatcher.stub!(:new).and_return(@default)
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
        'field' => 'bar', 'type' => 'exact'
      }).and_return(@exact)
      @master.add_matcher({'field' => 'bar', 'type' => 'exact'})
    end

    it "should create an default matcher" do
      Linkage::Matchers::DefaultMatcher.should_receive(:new).with({
        'field' => 'foo', 'formula' => 'a > b ? 100 : 0'
      }).and_return(@default)
      @master.add_matcher({'field' => 'foo', 'formula' => 'a > b ? 100 : 0'})
    end
  end

  describe "#score" do
    before(:each) do
      @record_1 = [1, 321, '123456789']
      @record_2 = [2, 123, '123456789']
      @record_3 = [3, 456, '867530999']
      @record_4 = [4, 0, 'blah']
      @exact.stub!(:score).with('123456789', ['123456789', '867530999', 'blah']).and_return([80, 60, 0])
      @default.stub!(:score).with(321, [123, 456, 0]).and_return([0, 100, 0])
    end

    describe "when using the mean combining method" do
      before(:each) do
        @master = create_master_with_matchers
      end

      it "should call score for each matcher when scoring two records" do
        @exact.should_receive(:score).with('123456789', ['123456789']).and_return([100])
        @default.should_receive(:score).with(321, [123]).and_return([0])
        @master.score(@record_1, @record_2)
      end

      it "should call score for each matcher when scoring four records" do
        @exact.should_receive(:score).with('123456789', ['123456789', '867530999', 'blah']).and_return([80, 60, 0])
        @default.should_receive(:score).with(321, [123, 456, 0]).and_return([0, 100, 0])
        @master.score(@record_1, [@record_2, @record_3, @record_4])
      end

      it "should return a hash of group arrays" do
        @master.score(@record_1, [@record_2, @record_3, @record_4]).should == {
          'good'  => [[1, 2, 40]],
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

      it "should return an array of sums" do
        @master.score(@record_1, [@record_2, @record_3, @record_4]).should == {
          'good'  => [[1, 2, 80]],
          'great' => [[1, 3, 160]]
        }
      end
    end
  end
end
