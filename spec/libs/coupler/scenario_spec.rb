require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Scenario do
  before(:each) do
    @logger  = stub(Logger, :debug => nil, :info => nil)
    Coupler.stub!(:logger).and_return(@logger)

    @options = Coupler::Options.new
    @resources = {}
    %w{scores birth death birth_scratch death_scratch}.each do |name|
      @resources[name.to_sym] = obj = stub("#{name} resource")
      Coupler::Resource.stub!(:find).with(name).and_return(obj)
    end

    @result  = stub(Coupler::Resource::ResultSet, :close => nil)
    @cache   = stub(Coupler::CachedResource, :add => nil, :fetch => nil, :clear => nil, :auto_fill! => nil)
    @matcher = stub(Coupler::Matcher::Master, :add_matcher => nil)
    Coupler::Matcher::Master.stub!(:new).and_return(@matcher)
    Coupler::CachedResource.stub!(:new).and_return(@cache)
  end

  def create_scenario(spec = {}, opts = {})
    spec = YAML.load(<<-EOF).merge( spec.is_a?(Hash) ? spec : YAML.load(spec) )
      name: family
      type: self-join
      resource: birth
      matchers:
        - field: MomSSN
          formula: '(!a.nil? && a == b) ? 100 : 0'
        - field: MomDOB
          formula: '(!a.nil? && a == b) ? 100 : 0'
      scoring:
        combining method: mean
        range: 50..100
    EOF
    @options.csv_output = true             if opts[:csv_output]
    Coupler::Scenario.new(spec, @options)
  end

  it "should raise an error for an unsupported type" do
    lambda { create_scenario("type: awesome") }.should raise_error("unsupported scenario type")
  end

  it "should have a name" do
    s = create_scenario
    s.name.should == 'family'
  end

  it "should have a range" do
    create_scenario.range.should == (50..100)
  end

  it "should have a combining method" do
    create_scenario.combining_method.should == 'mean'
  end

  it "should find the birth resource" do
    Coupler::Resource.should_receive(:find).with('birth').and_return(@resources[:birth])
    create_scenario
  end

  it "should raise an error if it can't find the resource" do
    Coupler::Resource.stub!(:find).and_return(nil)
    lambda { create_scenario }.should raise_error("can't find resource 'birth'")
  end

  it "should have a type of self-join" do
    s = create_scenario
    s.type.should == 'self-join'
  end

  it "should have resources" do
    s = create_scenario
    s.resources.should == [@resources[:birth]]
  end

  it "should create a master matcher" do
    Coupler::Matcher::Master.should_receive(:new).with(
      an_instance_of(Coupler::Scenario), @options
    ).and_return(@matcher)
    create_scenario
  end

  it "should add the SSN matcher" do
    @matcher.should_receive(:add_matcher).with('field' => 'MomSSN', 'formula' => '(!a.nil? && a == b) ? 100 : 0')
    create_scenario
  end

  it "should add the DOB matcher" do
    @matcher.should_receive(:add_matcher).with('field' => 'MomDOB', 'formula' => '(!a.nil? && a == b) ? 100 : 0')
    create_scenario
  end

  it "should have a field list" do
    s = create_scenario
    s.field_list.should == %w{MomSSN MomDOB}
  end

  it "should have indices when using exact matchers" do
    s = create_scenario(<<-EOF)
      matchers:
        - field: MomSSN
          formula: "(!a.nil? && a == b) ? 100 : 0"
        - field: MomDOB
          type: exact
    EOF
    s.indices.should == %w{MomDOB}
  end

  it "should have correct indices for an exact matcher with multiple fields" do
    s = create_scenario(<<-EOF)
      matchers:
        - fields: [MomSSN, MomDOB]
          type: exact
    EOF
    s.indices.should == [%w{MomSSN MomDOB}]
  end

  describe "when matching two resources together" do
    alias :orig_create_scenario :create_scenario
    def create_scenario(spec = {}, opts = {})
      spec = YAML.load(<<-EOF).merge( spec.is_a?(Hash) ? spec : YAML.load(spec) )
        type: dual-join
        resources: [birth, death]
        matchers:
          - field: BirthCertNum
            type: exact
      EOF
      orig_create_scenario(spec, opts)
    end

    it "should not raise an error for being a dual-join type" do
      lambda { create_scenario }.should_not raise_error("unsupported scenario type")
    end

    it "should find birth and death resources" do
      Coupler::Resource.should_receive(:find).with('birth').and_return(@resources[:birth])
      Coupler::Resource.should_receive(:find).with('death').and_return(@resources[:death])
      create_scenario
    end

    it "should find birth and death scratch resources" do
      Coupler::Resource.should_receive(:find).with('birth_scratch').and_return(@resources[:birth_scratch])
      Coupler::Resource.should_receive(:find).with('death_scratch').and_return(@resources[:death_scratch])
      create_scenario
    end

    it "should have resources" do
      s = create_scenario
      s.resources.should == @resources.values_at(:birth, :death)
    end

    it "should have scratches" do
      s = create_scenario
      s.scratches.should == @resources.values_at(:birth_scratch, :death_scratch)
    end
  end

  describe "#run" do

    def do_run(spec = {}, opts = {})
      create_scenario(spec, opts).run
    end

    before(:each) do
      @date_1 = Date.parse('1982-4-15')
      @date_2 = Date.parse('1980-9-4')
      @records = [
        [1, "123456789", @date_1],
        [2, "999999999", @date_2],
        [3, "123456789", @date_1],
        [4, "123456789", @date_2],
      ]
      @xrecords = [
        [1, "123456789", "1982-04-15"],
        [2,  nil,        "1980-09-04"],
        [3, "123456789", "1982-04-15"],
        [4, "123456789", "1980-09-04"],
      ]

      # resource setup
      @result.stub!(:next).and_return(*(@records + [nil]))
      @resources[:birth].stub!(:select).with({
        :columns => ["ID", "MomSSN", "MomDOB"], :order => "ID",
        :limit => 10000, :offset => 0
      }).and_return(@result)
      @resources[:birth].stub!(:count).and_return(4)

      # matcher setup
      @scores = stub(Coupler::Scores)
      @matcher.stub!(:score).and_return(@scores)
      [[1, 3, 100], [1, 4, 50], [2, 4, 50], [3, 4, 50]].inject(@scores.stub!(:each)) do |s, ary|
        s.and_yield(*ary)
      end
    end

    describe "when outputting csv's" do
      before(:each) do
        @scenario = create_scenario({}, :csv_output => true)
      end

      it "should output results in the result file" do
        expected = [
          %w{id1 id2 score},
          %w{1 3 100},
          %w{1 4 50},
          %w{2 4 50},
          %w{3 4 50}
        ]
        @scenario.run

        File.exist?("family.csv").should be_true
        FasterCSV.foreach("family.csv") do |row|
          row.should == expected.shift
        end
        expected.should be_empty
        File.delete("family.csv")
      end
    end

    it "should log the start of the run" do
      @logger.should_receive(:info).with("Scenario (family): Run start")
      do_run
    end

    it "should match all records" do
      @matcher.should_receive(:score).with(no_args()).and_return(@scores)
      do_run
    end
  end
end
