require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Linkage::Matchers::ExactMatcher do
  def create_matcher(options = {})
    Linkage::Matchers::ExactMatcher.new({
      'field' => 'ssn',
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
    end

    describe "when matching two records" do
      it "should return true score when equal" do
        @matcher.score("123456789", ["123456789"]).should == [100]
      end

      it "should return false score when not equal" do
        @matcher.score("123456789", ["bippityboppity"]).should == [0]
      end
    end

    describe "when matching several records" do
      it "should return an array of scores" do
        @matcher.score("123456789", [
          "123456789", "213456789", "123456789", "423156789"
        ]).should == [100, 0, 100, 0]
      end
    end
  end
end
