require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Scenario do
  before(:each) do
    @logger = stub(Logger, :debug => nil, :info => nil)
    Linkage.stub!(:logger).and_return(@logger)
  end

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
        ],
        'scoring' => {
          'formula' => 'scores.inject(0) { |sum, s| sum + s } / scores.length',
          'cutlist' => {
            'confident' => '100..100',
            'unsure'    => '50..99'
          }
        }
      }.merge(options)
      Linkage::Scenario.new(options)
    end

    before(:each) do
      @result       = stub(Linkage::Resource::ResultSet)
      @resource     = stub(Linkage::Resource, :table => "birth_all", :primary_key => "ID")
      @scratch      = stub(Linkage::Resource, {
        :create_table => nil, :insert => nil, :select_one => nil,
        :drop_table => nil
      })
      @cache        = stub(Linkage::Cache, :add => nil, :fetch => nil)
      @ssn_filter   = mock("ssn transformer")
      @date_changer = mock("date transformer")
      @ssn_matcher  = stub('SSN matcher', :field => 'MomSSN', :score => 100)
      @dob_matcher  = stub('DOB matcher', :field => 'MomDOB', :score => 100)
      Linkage::Resource.stub!(:find).with('birth').and_return(@resource)
      Linkage::Resource.stub!(:find).with('scratch').and_return(@scratch)
      Linkage::Transformer.stub!(:find).with('ssn_filter').and_return(@ssn_filter)
      Linkage::Transformer.stub!(:find).with('date_changer').and_return(@date_changer)
      Linkage::Scenario::Matcher.stub!(:new).with({
        'field' => 'MomSSN', 'formula' => '(!a.nil? && a == b) ? 100 : 0'
      }).and_return(@ssn_matcher)
      Linkage::Scenario::Matcher.stub!(:new).with({
        'field' => 'MomDOB', 'formula' => '(!a.nil? && a == b) ? 100 : 0'
      }).and_return(@dob_matcher)
      Linkage::Cache.stub!(:new).and_return(@cache)
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

    it "should not find a transformer if it does not relate to matchers" do
      Linkage::Transformer.should_not_receive(:find).with('decepticon').and_return("foo")
      s = create_scenario({
        'transformations' => [
          {
            'name'        => 'foo',
            'transformer' => 'decepticon',
            'arguments'   => {'baz' => 'bar'}
          },
        ]
      })
    end

    it "should raise an error if it can't find a transformer" do
      Linkage::Transformer.stub!(:find).and_return(nil)
      lambda { create_scenario }.should raise_error("can't find transformer 'ssn_filter'")
    end

    it "should find the birth resource" do
      Linkage::Resource.should_receive(:find).with('birth').and_return(@resource)
      create_scenario
    end

    it "should find the scratch resource" do
      Linkage::Resource.should_receive(:find).with('scratch').and_return(@scratch)
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
      
      def do_run(options = {})
        create_scenario(options).run
      end

      before(:each) do
        @date_1 = Date.parse('1982-4-15')
        @date_2 = Date.parse('1980-9-4')
        @record_1 = [1, "123456789", @date_1]
        @record_2 = [2, "999999999", @date_2]
        @record_3 = [3, "123456789", @date_1]
        @record_4 = [4, "123456789", @date_2]

        @all_result = stub("ResultSet (all)", :close => nil)
        @all_result.stub!(:next).and_return(
          [1, "123456789", @date_1],
          [2, "999999999", @date_2],
          [3, "123456789", @date_1],
          [4, "123456789", @date_2],
          nil
        )
        @resource.stub!(:select_num).with(an_instance_of(Fixnum), "ID", "MomSSN", "MomDOB", an_instance_of(Hash)).and_return(@all_result)
        @resource.stub!(:count).and_return(4)

        # cache setup
        @cache.stub!(:fetch).with(2).and_return { [2, nil, "1980-09-04"] }
        @cache.stub!(:fetch).with(3).and_return { [3, "123456789", "1982-04-15"] }
        @cache.stub!(:fetch).with(4).and_return { [4, "123456789", "1980-09-04"] }

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
        @dob_matcher.stub!(:score).with("1980-09-04", "1980-09-04").and_return(100)
      end

      it "should log the start of the run" do
        @logger.should_receive(:info).with("Scenario (family): Run start")
        do_run
      end

      it "should log comparisons" do
        @logger.should_receive(:debug).with("Scenario (family): Comparing record 1")
        @logger.should_receive(:debug).with("Scenario (family): Comparing record 2")
        @logger.should_receive(:debug).with("Scenario (family): Comparing record 3")
        do_run
      end

      it "should create a cache with the scratch database" do
        Linkage::Cache.should_receive(:new).with('scratch').and_return(@cache)
        do_run
      end

      it "should count number of records" do
        @resource.should_receive(:count).and_return(4)
        do_run
      end

      it "should select all needed fields for 1000 records at a time" do
        @resource.should_receive(:select_num).with(1000, "ID", "MomSSN", "MomDOB", :offset => 0).and_return(@all_result)
        s = create_scenario
        s.run
      end

      it "should select only certain records if given blocking conditions" do
        @resource.should_receive(:select).with({
          :columns => %w{ID MomSSN MomDOB}, :limit => 1000,
          :conditions => "MomSSN NOT IN ('111111111', '222222222')",
          :offset => 0
        }).and_return(@all_result)
        do_run('blocking' => "MomSSN NOT IN ('111111111', '222222222')")
      end

      it "should select fields needed to transform a matcher field" do
        # stub transformer
        convoy = stub("optimus prime is called convoy in japan")
        convoy.stub!(:transform).and_return("optimus-prime")
        Linkage::Transformer.stub!(:find).with('convoy').and_return(convoy)
        s = create_scenario({
          'transformations' => [{
            'name' => 'MomSSN', 'transformer' => 'convoy',
            'arguments' => { 'ssn' => 'MomSSN', 'stuff' => 'junk' }
          }]
        })

        @resource.should_receive(:select_num).with(1000, 'ID', 'MomSSN', 'MomDOB', 'junk', :offset => 0).and_return(@all_result)
        s.run
      end

      it "should transform the first record" do
        @ssn_filter.should_receive(:transform).with('ssn' => '123456789').at_least(1).times.and_return('123456789')
        @date_changer.should_receive(:transform).with('date' => @date_1).at_least(1).times.and_return(@date_1.to_s)
        s = create_scenario
        s.run
      end

      it "should drop the table from the scratch resource" do
        @scratch.should_receive(:drop_table).with("birth_all")
        do_run
      end

      it "should setup the scratch resource with all needed columns" do
        @scratch.should_receive(:create_table).with("birth_all", "ID int", "MomSSN varchar(255)", "MomDOB varchar(255)")
        s = create_scenario
        s.run
      end

      it "should transform the other records" do
        @ssn_filter.should_receive(:transform).with('ssn' => '123456789').exactly(3).times.and_return('123456789')
        @date_changer.should_receive(:transform).with('date' => @date_1).twice.and_return(@date_1.to_s)
        @date_changer.should_receive(:transform).with('date' => @date_2).twice.and_return(@date_2.to_s)
        s = create_scenario
        s.run
      end

      it "should insert the transformed records into scratch" do
        fields = %w{ID MomSSN MomDOB}
        @scratch.should_receive(:insert).with(fields, [2, nil, "1980-09-04"])
        @scratch.should_receive(:insert).with(fields, [3, "123456789", "1982-04-15"])
        @scratch.should_receive(:insert).with(fields, [4, "123456789", "1980-09-04"])
        s = create_scenario
        s.run
      end

      it "should add the records into the cache" do
        @cache.should_receive(:add).with(2, [2, nil, "1980-09-04"])
        @cache.should_receive(:add).with(3, [3, "123456789", "1982-04-15"])
        @cache.should_receive(:add).with(4, [4, "123456789", "1980-09-04"])
        do_run
      end

      it "should match first record to rest" do
        @ssn_matcher.should_receive(:score).with("123456789", nil).at_least(1).times.and_return(0)
        @ssn_matcher.should_receive(:score).with("123456789", "123456789").at_least(2).times.and_return(100)
        @dob_matcher.should_receive(:score).with("1982-04-15", "1980-09-04").at_least(2).times.and_return(0)
        @dob_matcher.should_receive(:score).with("1982-04-15", "1982-04-15").at_least(1).times.and_return(0)
        s = create_scenario
        s.run
      end

      it "should select 1000 more records if it runs out" do
        count = 0
        result1 = stub("first 1000", :close => nil)
        result1.stub!(:next).and_return([count, "123456789", @date_1], nil)
        result2 = stub("second 1000", :close => nil)
        result2.stub!(:next).and_return([count, "123456789", @date_1], nil)

        @resource.stub!(:count).and_return(2000)
        @resource.should_receive(:select_num).with(1000, "ID", "MomSSN", "MomDOB", :offset => 0).and_return(result1)
        @resource.should_receive(:select_num).with(1000, "ID", "MomSSN", "MomDOB", :offset => 1000).and_return(result2)
        do_run
      end

      it "should fetch records from the cache for further comparisons" do
        @cache.should_receive(:fetch).with(2).and_return { [2, nil, "1980-09-04"] }
        @cache.should_receive(:fetch).with(3).twice.and_return { [3, "123456789", "1982-04-15"] }
        @cache.should_receive(:fetch).with(4).exactly(3).times.and_return { [4, "123456789", "1980-09-04"] }
        do_run
      end

      it "should not be boned if there are no transformers" do
        do_run('transformations' => nil)
      end

      it "should match all records" do
        @ssn_matcher.should_receive(:score).with("123456789", nil).once.and_return(0)
        @ssn_matcher.should_receive(:score).with("123456789", "123456789").exactly(3).times.and_return(100)
        @ssn_matcher.should_receive(:score).with(nil, "123456789").twice.and_return(0)
        @dob_matcher.should_receive(:score).with("1982-04-15", "1980-09-04").exactly(3).times.and_return(0)
        @dob_matcher.should_receive(:score).with("1982-04-15", "1982-04-15").once.and_return(100)
        @dob_matcher.should_receive(:score).with("1980-09-04", "1980-09-04").once.times.and_return(100)
        @dob_matcher.should_receive(:score).with("1980-09-04", "1982-04-15").once.times.and_return(0)
        s = create_scenario
        s.run
      end

      it "should return a hash of score means" do
        s = create_scenario
        s.run.should == {
          'confident' => [
            [1, 3, 100]
          ],
          'unsure' => [
            [1, 4, 50],
            [2, 4, 50],
            [3, 4, 50]
          ]
        }
      end

      it "should return a hash of score sums" do
        s = create_scenario({
          'scoring' => {
            'formula' => 'scores.inject(0) { |sum, s| sum + s }',
            'cutlist' => {
              'confident' => '200..200',
              'unsure'    => '100..199'
            }
          }
        })
        s.run.should == {
          'confident' => [
            [1, 3, 200]
          ],
          'unsure' => [
            [1, 4, 100],
            [2, 4, 100],
            [3, 4, 100]
          ]
        }
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
