require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Matchers::ExactMatcher do
  before(:each) do
    @record_set = stub("record result set", :close => nil)
    @resources = [
      stub("resource one", :primary_key => "id",  :select => @record_set),
      stub("resource two", :primary_key => "id2", :select => @record_set)
    ]
    @options = Coupler::Options.new
  end

  def create_matcher(spec = {}, opts = {})
    Coupler::Matchers::ExactMatcher.new({
      'fields'    => %w{ssn},
      'type'      => 'exact',
      'resources' => @resources
    }.merge(spec), @options)
  end

  it "should account for sorting differences in databases and Ruby"

  it "should have a default true_score" do
    m = create_matcher
    m.true_score.should == 100
  end

  it "should have a default false_score" do
    m = create_matcher
    m.false_score.should == 0
  end

  it "should have custom true/false scores" do
    m = create_matcher('scores' => [25, 75])
    m.true_score.should == 75
    m.false_score.should == 25
  end

  it "should have multiple fields" do
    m = Coupler::Matchers::ExactMatcher.new({
      'fields'    => %w{ssn dob}, 
      'type'      => 'exact',
      'resources' => @resources
    }, @options)
    m.fields.should == %w{ssn dob}
  end

  it "should have one field" do
    m = Coupler::Matchers::ExactMatcher.new({
      'field'     => 'ssn', 
      'type'      => 'exact',
      'resources' => @resources
    }, @options)
    m.fields.should == %w{ssn}
  end

  describe "#score" do
    before(:each) do
      @recorder = stub(Coupler::Scores::Recorder, :add => nil)
      @nil_set  = stub("nil set", :close => nil, :next => nil)
    end

    describe "in self-join mode" do
      before(:each) do
        @resources.pop
        @matcher = create_matcher
      end

      describe "on one field" do
        before(:each) do
          @record_set.stub!(:next).and_return(
            [1, "123456789"],
            [3, "123456789"],
            [5, "123456789"],
            [4, "423156789"],
            [2, "bippityboppity"],
            nil
          )
        end

        it "should select from resource, ordering by field and avoiding nulls" do
          @resources[0].should_receive(:select).with({
            :columns => ['id', 'ssn'], :order => 'ssn',
            :auto_refill => true, :conditions => "WHERE ssn IS NOT NULL"
          }).and_return(@record_set)
          @matcher.score(@recorder)
        end

        it "should add matches to the recorder" do
          @recorder.should_receive(:add).with(1, 3, 100)
          @recorder.should_receive(:add).with(1, 5, 100)
          @recorder.should_receive(:add).with(3, 5, 100)
          @matcher.score(@recorder)
        end
      end

      describe "on multiple fields" do
        before(:each) do
          @matcher = create_matcher('fields' => %w{ssn dob})
          @record_set.stub!(:next).and_return(
            [1, "123456789", "1969-01-01"],
            [3, "123456789", "1969-01-01"],
            [5, "123456789", "1969-01-01"],
            [6, "123456789", "1975-01-01"],
            [4, "423156789", "2000-01-01"],
            [2, "bippityboppity", "2002-01-01"],
            nil
          )
        end

        it "should select from resource, ordering by all fields" do
          @resources[0].should_receive(:select).with({
            :columns => ['id', 'ssn', 'dob'], :order => 'ssn, dob', 
            :auto_refill => true, :conditions => "WHERE ssn IS NOT NULL AND dob IS NOT NULL"
          }).and_return(@record_set)
          @matcher.score(@recorder)
        end

        it "should add matches to the recorder" do
          @recorder.should_receive(:add).with(1, 3, 100)
          @recorder.should_receive(:add).with(1, 5, 100)
          @recorder.should_receive(:add).with(3, 5, 100)
          @recorder.should_not_receive(:add).with(anything(), 6, anything())
          @matcher.score(@recorder)
        end
      end
    end

    describe "in dual-join mode" do
      before(:each) do
      end

      describe "on one field" do
        before(:each) do
          @matcher = create_matcher('fields' => %w{fruit})
          @record_set1 = stub("record set one")
          @record_set1.stub!(:next).and_return(
            [1, "apple"], [3, "apple"], [5, "banana"],
            [4, "kiwi"], [2, "orange"], nil
          )
          @resources[0].stub!(:select).and_return(@record_set1)

          @record_set2 = stub("record set one")
          @record_set2.stub!(:next).and_return(
            [6, "apple"], [8, "banana"], [7, "orange"], 
            [10, "orange"], [9, "pineapple"], nil
          )
          @resources[1].stub!(:select).and_return(@record_set2)
        end

        it "should select from each resource, ordering by field and avoiding nulls" do
          @resources[0].should_receive(:select).with({
            :columns => ['id', 'fruit'], :order => 'fruit',
            :auto_refill => true, :conditions => "WHERE fruit IS NOT NULL"
          }).and_return(@record_set1)
          @resources[1].should_receive(:select).with({
            :columns => ['id2', 'fruit'], :order => 'fruit',
            :auto_refill => true, :conditions => "WHERE fruit IS NOT NULL"
          }).and_return(@record_set2)
          @matcher.score(@recorder)
        end

        it "should add matches to the recorder" do
          @recorder.should_receive(:add).with(1, 6, 100)
          @recorder.should_receive(:add).with(3, 6, 100)
          @recorder.should_receive(:add).with(5, 8, 100)
          @recorder.should_receive(:add).with(2, 7, 100)
          @recorder.should_receive(:add).with(2, 10, 100)
          @matcher.score(@recorder)
        end
      end

      describe "on multiple fields" do
        before(:each) do
          @matcher = create_matcher('fields' => %w{fruit veggie})
          @record_set1 = stub("record set one")
          @record_set1.stub!(:next).and_return(
            [1, "apple", "lettuce"], [2, "apple",  "lettuce"],
            [3, "apple", "yam"],     [4, "banana", "carrot"],
            [4, "kiwi",  "rhubarb"], [5, "orange", "peanut"],
            nil
          )
          @resources[0].stub!(:select).and_return(@record_set1)

          @record_set2 = stub("record set one")
          @record_set2.stub!(:next).and_return(
            [1, "apple",  "lettuce"], [2, "banana", "carrot"],
            [5, "mango",  "zany"],    [3, "orange", "peanut"],
            [4, "orange", "peanut"],  nil
          )
          @resources[1].stub!(:select).and_return(@record_set2)
        end

        it "should select from each resource, ordering by all fields and avoiding nulls" do
          @resources[0].should_receive(:select).with({
            :columns => %w{id fruit veggie}, 
            :order => "fruit, veggie", :auto_refill => true,
            :conditions => "WHERE fruit IS NOT NULL AND veggie IS NOT NULL"
          }).and_return(@record_set1)
          @resources[1].should_receive(:select).with({
            :columns => %w{id2 fruit veggie}, 
            :order => "fruit, veggie", :auto_refill => true,
            :conditions => "WHERE fruit IS NOT NULL AND veggie IS NOT NULL"
          }).and_return(@record_set2)
          @matcher.score(@recorder)
        end

        it "should add matches to the recorder" do
          @recorder.should_receive(:add).with(1, 1, 100)
          @recorder.should_receive(:add).with(2, 1, 100)
          @recorder.should_receive(:add).with(4, 2, 100)
          @recorder.should_receive(:add).with(5, 3, 100)
          @recorder.should_receive(:add).with(5, 4, 100)
          @matcher.score(@recorder)
        end
      end
    end
  end
end
