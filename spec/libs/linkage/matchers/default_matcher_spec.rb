require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Linkage::Matchers::DefaultMatcher do
  def create_matcher(options = {})
    Linkage::Matchers::DefaultMatcher.new({
      'field'   => 'MomSSN',
      'formula' => '(!a.nil? && a == b) ? 100 : 0'
    }.merge(options))
  end

  before(:each) do
    @matcher = create_matcher
  end

  it "should have a field" do
    @matcher.field.should == 'MomSSN'
  end

  it "should score values based on the scoring function" do
    @matcher.score("123456789", ["987654321"]).should == [0]
  end

  it "should score multiple values and return an array of scores" do
    @matcher.score("123456789", ["blah", "123456789"]).should == [0, 100]
  end
end
