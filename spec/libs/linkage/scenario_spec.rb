require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Scenario do
  describe 'when self-joining' do
    def create_scenario(options = {})
      options = {
        'name'     => 'family', 
        'type'     => 'self-join',
        'resource' => 'birth',
        'transformations' => [
          {
            'name'        => 'MomSSN',
            'transformer' => 'ssn_filter',
            'arguments'   => {'ssn' => 'MomSSN'}
          },
          {
            'name'        => 'MomDOB',
            'transformer' => 'date_changer',
            'arguments'   => {'date' => 'MomDOB'}
          }
        ],
        'matchers' => [
          {
            'field'   => 'MomSSN',
            'formula' => '(!a.nil? && a == b) ? 100 : 0'
          },
          {
            'field'   => 'MomDOB',
            'formula' => '(!a.nil? && a == b) ? 100 : 0'
          }
        ]
      }.merge(options)
      Linkage::Scenario.new(options)
    end

    before(:each) do
      @table        = stub("Resource table", :primary_key => "ID")
      @resource     = stub(Linkage::Resource, :record => @table)
      @ssn_filter   = mock(Linkage::Transformer)
      @date_changer = mock(Linkage::Transformer)
      @ssn_matcher  = stub('SSN matcher', :field => 'MomSSN', :score => 100)
      @dob_matcher  = stub('DOB matcher', :field => 'MomDOB', :score => 100)
      Linkage::Resource.stub!(:find).and_return(@resource)
      Linkage::Transformer.stub!(:find).with('ssn_filter').and_return(@ssn_filter)
      Linkage::Transformer.stub!(:find).with('date_changer').and_return(@date_changer)
      Linkage::Scenario::Matcher.stub!(:new).with({
        'field' => 'MomSSN', 'formula' => '(!a.nil? && a == b) ? 100 : 0'
      }).and_return(@ssn_matcher)
      Linkage::Scenario::Matcher.stub!(:new).with({
        'field' => 'MomDOB', 'formula' => '(!a.nil? && a == b) ? 100 : 0'
      }).and_return(@dob_matcher)
    end

    it "should have a name" do
      s = create_scenario
      s.name.should == 'family'
    end

    it "should have a type of self-join" do
      s = create_scenario
      s.type.should == 'self-join'
    end

    it "should find the ssn_filter transformer" do
      Linkage::Transformer.should_receive(:find).with('ssn_filter').and_return(@ssn_filter)
      create_scenario
    end

    it "should find the date_change transformer" do
      Linkage::Transformer.should_receive(:find).with('date_changer').and_return(@date_changer)
      create_scenario
    end

    it "should raise an error if it can't find a transformer" do
      Linkage::Transformer.stub!(:find).and_return(nil)
      lambda { create_scenario }.should raise_error("can't find transformer 'ssn_filter'")
    end

    it "should find the birth resource" do
      Linkage::Resource.should_receive(:find).with('birth').and_return(@resource)
      create_scenario
    end

    it "should raise an error if it can't find the resource" do
      Linkage::Resource.stub!(:find).and_return(nil)
      lambda { create_scenario }.should raise_error("can't find resource 'birth'")
    end

    it "should not raise an error if there are no transformations" do
      create_scenario('transformations' => nil)
    end

    it "should create the SSN matcher" do
      Linkage::Scenario::Matcher.should_receive(:new).with({
        'field' => 'MomSSN', 'formula' => '(!a.nil? && a == b) ? 100 : 0'
      }).and_return(@ssn_matcher)
      create_scenario
    end

    it "should create the DOB matcher" do
      Linkage::Scenario::Matcher.should_receive(:new).with({
        'field' => 'MomDOB', 'formula' => '(!a.nil? && a == b) ? 100 : 0'
      }).and_return(@dob_matcher)
      create_scenario
    end

    describe "#run" do
      before(:each) do
        @date_1 = Date.parse('1982-4-15')
        @date_2 = Date.parse('1980-9-4')

        @record_1 = stub("Birth record", {
          :attributes => {
            "ID" => 1,
            "MomSSN" => "123456789",
            "MomDOB" => @date_1
          }
        })
        @record_2 = stub("Birth record", {
          :attributes => {
            "ID" => 2,
            "MomSSN" => "999999999",
            "MomDOB" => @date_2
          }
        })
        @record_3 = stub("Birth record", {
          :attributes => {
            "ID" => 3,
            "MomSSN" => "123456789",
            "MomDOB" => @date_1
          }
        })

        @table.stub!(:find).and_return([@record_1, @record_2, @record_3])
        @ssn_filter.stub!(:transform).with('ssn' => '123456789').and_return('123456789')
        @ssn_filter.stub!(:transform).with('ssn' => '999999999').and_return(nil)
        @date_changer.stub!(:transform).with('date' => @date_1).and_return(@date_1.to_s)
        @date_changer.stub!(:transform).with('date' => @date_2).and_return(@date_2.to_s)
        @ssn_matcher.stub!(:score).with("123456789", nil).and_return(0)
        @ssn_matcher.stub!(:score).with(nil, "123456789").and_return(0)
        @ssn_matcher.stub!(:score).with("123456789", "123456789").and_return(100)
        @dob_matcher.stub!(:score).with("1982-04-15", "1980-09-04").and_return(0)
        @dob_matcher.stub!(:score).with("1980-09-04", "1982-04-15").and_return(0)
        @dob_matcher.stub!(:score).with("1982-04-15", "1982-04-15").and_return(100)
      end

      it "should find all records from its resource" do
        @table.should_receive(:find).with(:all).and_return([@record_1, @record_2, @record_3])
        s = create_scenario
        s.run
      end

      it "should transform ssn's" do
        @ssn_filter.should_receive(:transform).with('ssn' => '123456789').twice.and_return('123456789')
        @ssn_filter.should_receive(:transform).with('ssn' => '999999999').once.and_return(nil)
        s = create_scenario
        s.run
      end

      it "should transform dates" do
        @date_changer.should_receive(:transform).with('date' => @date_1).twice.and_return(@date_1.to_s)
        @date_changer.should_receive(:transform).with('date' => @date_2).once.and_return(@date_2.to_s)
        s = create_scenario
        s.run
      end

      it "should match the first two records" do
        @ssn_matcher.should_receive(:score).with("123456789", nil).and_return(0)
        @dob_matcher.should_receive(:score).with("1982-04-15", "1980-09-04").and_return(0)
        s = create_scenario
        s.run
      end

      it "should match the first and third records" do
        @ssn_matcher.should_receive(:score).with("123456789", "123456789").and_return(100)
        @dob_matcher.should_receive(:score).with("1982-04-15", "1982-04-15").and_return(100)
        s = create_scenario
        s.run
      end

      it "should match the second and third records" do
        @ssn_matcher.should_receive(:score).with(nil, "123456789").and_return(0)
        @dob_matcher.should_receive(:score).with("1980-09-04", "1982-04-15").and_return(0)
        s = create_scenario
        s.run
      end

      it "should return a hash of scores" do
        s = create_scenario
        s.run.should == { 1 => { 2 => [0, 0], 3 => [100, 100] }, 2 => { 3 => [0, 0] } }
      end
    end
  end
end

describe Linkage::Scenario::Matcher do
  def create_matcher(options = {})
    Linkage::Scenario::Matcher.new({
      'field'   => 'MomSSN',
      'formula' => '(!a.nil? && a == b) ? 100 : 0'
    }.merge(options))
  end

  it "should have a field" do
    m = create_matcher
    m.field.should == 'MomSSN'
  end

  it "should score values based on the scoring function" do
    m = create_matcher
    m.score("123456789", "987654321").should == 0
  end
end
