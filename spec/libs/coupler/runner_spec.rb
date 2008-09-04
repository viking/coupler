require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::Runner do
  @@crap = {
    :fields => {
      'leetsauce_foo' => %w{foo bar},
      'leetsauce_bar' => %w{foo zoidberg},
      'weaksauce_foo' => %w{foo nixon},
      'mayhem_pants'  => %w{pants shirt},
      'leetsauce_weaksauce' => %w{farnsworth}
    },
    :indices => {
      'leetsauce_foo' => [%w{foo bar}],
      'leetsauce_bar' => [%w{foo zoidberg}],
      'weaksauce_foo' => %w{foo nixon},
      'mayhem_pants'  => %w{pants shirt},
      'leetsauce_weaksauce' => %w{farnsworth}
    },
    :sql_types => {
      'leetsauce_foo' => 'same as foo',
      'leetsauce_bar' => 'int',
      'leetsauce_farnsworth' => 'same as wong',
      'weaksauce_foo' => 'same as wicked',
      'weaksauce_farnsworth' => 'same as brannigan'
    },
    :sql_formulae => {
      'leetsauce_foo' => nil,
      'leetsauce_bar' => "(IF(zoidberg < 10, nixon * 10, zoidberg / 5)) AS bar",
      'leetsauce_farnsworth' => '(wong) AS farnsworth',
      'weaksauce_foo' => nil,
      'weaksauce_farnsworth' => '(brannigan) AS farnsworth',
    }
  }

  @@data = {
    'leetsauce' => [
      [1, "123456789", 10, 10, "one"], [2, "234567891", 20, 20, "two"],
      [3, "345678912", 30, 30, "three"], [4, "444444444", 40, 40, "four"],
      [5, "567891234", 50, 50, "five"]
    ],
    'weaksauce' => [
      [1, "111111111", 100, "one"], [2, "222222222", 200, "two"],
      [3, "333333333", 300, "three"], [4, "456789123", 400, "four"],
      [5, "555555555", 500, "five"]
    ],
    'mayhem' => [
      [1, "khakis", "polo"], [2, "jeans", "t-shirt"], [3, "skirt", "blouse"],
      [4, "shorts", "tanktop"], [5, "trunks", "none"]
    ]
  }

  # this is a pretty excessive, but i don't feel like dreaming up some other
  # mocking system :(
  before(:each) do
    fixture_file = File.expand_path(File.dirname(__FILE__) + "/../../fixtures/sauce.yml")
    @raw_spec = YAML.load_file(fixture_file)
    @options  = Coupler::Options.new
    @options.filename = fixture_file
    Coupler::Options.stub!(:parse).and_return(@options)

    @scores = stub(Coupler::Scores)
    @scores.stub!(:each).and_yield(1, 2, 100).and_yield(1, 3, 85).and_yield(1, 4, 60)

    @sets      = {}
    @buffers   = {}
    @resources = {}
    @scratches = {}
    %w{leetsauce weaksauce mayhem scores}.each do |name|
      if name != 'scores'
        @sets[name] = stub("#{name} records", :next => nil, :close => nil)
        @buffers[name] = stub("insert buffer for #{name}", :flush! => nil, :<< => nil)
        @scratches[name] = stub("#{name} scratch resource", :name => "#{name}_scratch", :create_table => nil, :drop_table => nil, :insert_buffer => @buffers[name])
        Coupler::Resource.stub!(:new).with(hash_including('name' => "#{name}_scratch"), @options).and_return(@scratches[name])
      end
      @resources[name] = stub("#{name} resource", :name => name, :select => @sets[name], :primary_key => name == "mayhem" ? "demolition" : "id", :adapter => 'mysql')
      Coupler::Resource.stub!(:new).with(hash_including('name' => name), @options).and_return(@resources[name])
    end

    @scenarios = {}
    %w{leetsauce weaksauce mayhem}.zip([%w{foo bar weaksauce}, %w{foo}, %w{pants}]).each do |main, subs|
      subs.each do |sub|
        name = "#{main}_#{sub}"
        resources = [ @resources[main] ]
        resources << @resources[sub]  if sub == "weaksauce"
        @scenarios[name] = obj = stub("#{name} scenario", {
          :name => name, :resources => resources, :field_list => @@crap[:fields][name],
          :indices => @@crap[:indices][name], :run => @scores
        })
        Coupler::Scenario.stub!(:new).with(hash_including({'name' => name}), @options).and_return(obj)
      end
    end
  end

  def create_runner
    Coupler::Runner.new
  end

  it "should parse command line arguments" do
    ARGV.clear; ARGV.push("foo.yml", "--db-limit", "10")
    Coupler::Options.should_receive(:parse).with(ARGV).and_return(@options)
    create_runner
  end

  it "should have options" do
    create_runner.options.should == @options
  end

  it "should have a specification" do
    create_runner.specification.should == YAML.load_file(@options.filename)
  end

  it "should use custom options if given" do
    Coupler::Options.should_not_receive(:parse).and_return(@options)
    Coupler::Runner.new(@options)
  end

  it "should use a custom specification if given" do
    @options.specification = YAML.load_file(@options.filename)
    @options.filename = nil
    Coupler::Runner.new(@options).specification.should == @options.specification
  end

  it "should use Coupler::Specification to build a spec" do
    obj = YAML.load_file(@options.filename)
    obj.extend(Coupler::Specification)
    Coupler::Specification.should_receive(:parse_file).with(@options.filename).and_return(obj)
    Coupler::Specification.should_receive(:validate!).with(obj).and_return(obj)
    create_runner
  end

  it "should print specification errors and exit" do
    @options.filename = File.expand_path(File.dirname(__FILE__) + "/../../fixtures/bogus.yml")
    lambda { create_runner }.should raise_error(RuntimeError)
  end

  it "should create a new resource for each item in 'resources'" do
    @resources.each_pair do |name, obj|
      Coupler::Resource.should_receive(:new).with(hash_including('name' => name.to_s), @options).and_return(obj)
    end
    create_runner
  end

  it "should create a 'scratch' resource for each of the scenario's resources" do
    Coupler::Resource.should_receive(:new).with({
      'name'  => 'leetsauce_scratch',
      'table' => {'name' => 'leetsauce', 'primary key' => 'id'},
      'connection' => {'database' => 'db/scratch.sql', 'adapter' => 'sqlite3'}
    }, @options).and_return(@scratches['leetsauce'])
    Coupler::Resource.should_receive(:new).with({
      'name'  => 'weaksauce_scratch',
      'table' => {'name' => 'weaksauce', 'primary key' => 'id'},
      'connection' => {'database' => 'db/scratch.sql', 'adapter' => 'sqlite3'}
    }, @options).and_return(@scratches['weaksauce'])
    Coupler::Resource.should_receive(:new).with({
      'name'  => 'mayhem_scratch',
      'table' => {'name' => 'mayhem', 'primary key' => 'demolition'},
      'connection' => {'database' => 'db/scratch.sql', 'adapter' => 'sqlite3'}
    }, @options).and_return(@scratches['mayhem'])
    create_runner
  end

  it "should create a new scenario for each item in 'scenarios'" do
    @scenarios.each_pair do |name, obj|
      Coupler::Scenario.should_receive(:new).with(hash_including('name' => name.to_s), @options).and_return(obj)
    end
    create_runner
  end

  it "should require a scratch database resource" do
    @raw_spec["resources"].delete_if { |x| x['name'] == 'scratch' }
    @options.specification = @raw_spec
    lambda { create_runner }.should raise_error
  end

  it "should require a scores database resource" do
    @raw_spec["resources"].delete_if { |x| x['name'] == 'scores' }
    @options.specification = @raw_spec
    lambda { create_runner }.should raise_error
  end

  it "should not freak if there are no transformers" do
    @raw_spec.delete('transformations')
    @options.specification = @raw_spec
    lambda { create_runner }.should_not raise_error
  end

  describe "#run" do
    before(:each) do
      @runner = create_runner
    end

    it "should run each scenario" do
      @scenarios.values.each do |scenario|
        scenario.should_receive(:run).and_return(@scores)
      end
      @runner.run
    end
  end

  describe "#transform" do
    before(:each) do
      # transformers
      @transformer_classes = {}
      %w{foo_filter bar_bender renamer}.each do |name|
        @transformer_classes[name] = obj = stub("#{name} transformer class")
        Coupler::Transformer.stub!(:[]).with(name).and_return(obj)
      end

      @transformers = {}
      @raw_spec['transformations']['resources'].each_pair do |rname, xfs|
        xfs.each do |xf|
          name = "#{rname}_#{xf['field']}"
          @transformers[name] = obj = stub(name, :sql_type => @@crap[:sql_types][name], :arguments => xf['arguments'], :transform => "wee!", :sql => @@crap[:sql_formulae][name], :has_sql? => !!@@crap[:sql_formulae][name], :field_list= => nil)
          @transformer_classes[xf['function']].stub!(:new).with(xf).and_return(obj)
        end
      end
      Coupler::Transformer.stub!(:build)

      @resources['leetsauce'].stub!(:columns).and_return({'id' => 'int', 'foo' => 'varchar(9)', 'zoidberg' => 'int(11)', 'wong' => 'varchar(30)'})
      @resources['weaksauce'].stub!(:columns).and_return({'id' => 'int', 'wicked' => 'varchar(9)', 'nixon' => 'int', 'brannigan' => 'varchar(30)'})
      @resources['mayhem'].stub!(:columns).and_return({'demolition' => 'int', 'pants' => 'varchar(7)', 'shirt' => 'varchar(8)'})

      %w{leetsauce weaksauce mayhem}.each do |name|
        @sets[name].stub!(:next).and_return( *(@@data[name] + [nil]) )
      end

      @runner = create_runner
    end

    it "should build a custom transformer class for each in transformations/functions" do
      %w{foo_filter bar_bender}.each do |name|
        Coupler::Transformer.should_receive(:build).with(hash_including('name' => name))
      end
      @runner.transform
    end

    it "should create a new transformer instance for each transformation" do
      @raw_spec['transformations']['resources'].each_pair do |rname, xfs|
        xfs.each do |xf|
          name = "#{rname}_#{xf['field']}"
          @transformer_classes[xf['function']].should_receive(:new).with(xf).at_least(:once).and_return(@transformers[name])
        end
      end
      @runner.transform
    end

    it "should drop pre-existing scratch tables" do
      @scratches.each_pair do |name, obj|
        obj.should_receive(:drop_table).with(name)
      end
      @runner.transform
    end

    it "should get column info about all necessary fields" do
      @resources['leetsauce'].should_receive(:columns) do |arg|
        arg.sort.should == %w{foo id wong zoidberg}
        {'id' => 'int', 'foo' => 'varchar(9)', 'zoidberg' => 'int(11)', 'wong' => 'varchar(30)'}
      end
      @resources['weaksauce'].should_receive(:columns) do |arg|
        arg.sort.should == %w{brannigan id nixon wicked}
        {'id' => 'int', 'wicked' => 'varchar(9)', 'nixon' => 'int', 'brannigan' => 'varchar(30)'}
      end
      @resources['mayhem'].should_receive(:columns) do |arg|
        arg.sort.should == %w{demolition pants shirt}
        {'demolition' => 'int', 'pants' => 'varchar(7)', 'shirt' => 'varchar(8)'}
      end
      @runner.transform
    end

    it "should create one scratch table for each resource used" do
      @scratches['leetsauce'].should_receive(:create_table).with(
        'leetsauce',
        ["id int", "foo varchar(9)", "bar int", "zoidberg int(11)", "farnsworth varchar(30)"],
        [["foo", "bar"], ["foo", "zoidberg"], "farnsworth"]
      )
      @scratches['weaksauce'].should_receive(:create_table).with(
        'weaksauce',
        ["id int", "foo varchar(9)", "nixon int", "farnsworth varchar(30)"],
        ["foo", "nixon", "farnsworth"]
      )
      @scratches['mayhem'].should_receive(:create_table).with(
        'mayhem', ["demolition int", "pants varchar(7)", "shirt varchar(8)"], ["pants", "shirt"]
      )
      @runner.transform
    end

    it "should assign field_list for the necessary transformers" do
      @transformers['leetsauce_foo'].should_receive(:field_list=).with(%w{id foo bar zoidberg farnsworth})
      @transformers['weaksauce_foo'].should_receive(:field_list=).with(%w{id wicked nixon farnsworth})
      @runner.transform
    end

    it "should send the adapter name when getting a sql string" do
      @transformers['leetsauce_bar'].should_receive(:sql).with('mysql').and_return(@@crap[:sql_formulae]['leetsauce_bar'])
      @runner.transform
    end

    it "should select all necessary fields from leetsauce, including sql functions" do
      @resources['leetsauce'].should_receive(:select) do |hsh|
        hsh[:auto_refill].should be_true
        hsh[:columns].should == [
          "id", "foo", "(IF(zoidberg < 10, nixon * 10, zoidberg / 5)) AS bar",
          "zoidberg", "(wong) AS farnsworth"
        ]
        hsh[:order].should == "id"
        @sets['leetsauce']
      end
      @runner.transform
    end

    it "should select all necessary fields from leetsauce when no mysql formula is given for the bar transformer" do
      @transformers['leetsauce_bar'].should_receive(:sql).with('mysql').and_return(nil)
      @resources['leetsauce'].should_receive(:select) do |hsh|
        (%w{zoidberg nixon} - hsh[:columns]).should == []
        @sets['leetsauce']
      end
      @runner.transform
    end

    it "should select all needed fields from weaksauce" do
      @resources['weaksauce'].should_receive(:select) do |hsh|
        hsh[:auto_refill].should be_true
        hsh[:columns].should == [
          "id", "wicked", "nixon", "(brannigan) AS farnsworth"
        ]
        hsh[:order].should == "id"
        @sets['weaksauce']
      end
      @runner.transform
    end

    it "should select all needed fields from mayhem" do
      @resources['mayhem'].should_receive(:select) do |hsh|
        hsh[:auto_refill].should be_true
        hsh[:columns].sort.should == %w{demolition pants shirt}
        hsh[:order].should == "demolition"
        @sets['mayhem']
      end
      @runner.transform
    end

    it "should transform all records in leetsauce" do
      @@data['leetsauce'].each do |record|
        @transformers['leetsauce_foo'].should_receive(:transform).with(record) do |arg|
          arg[1] =~ /4{9}/ ? nil : arg[1]
        end
      end
      @transformers['leetsauce_bar'].should_not_receive(:transform).and_return('blah')
      @runner.transform
    end

    it "should transform all records in weaksauce" do
      @@data['weaksauce'].each do |record|
        @transformers['weaksauce_foo'].should_receive(:transform).with(record) do |arg|
          arg[1] =~ /4{9}/ ? nil : arg[1]
        end
      end
      @transformers['weaksauce_bar'].should_not_receive(:transform).and_return('blah')
      @runner.transform
    end

    it "should create an insert buffer from the scratch resource for each resource" do
      @scratches['leetsauce'].should_receive(:insert_buffer).with(%w{id foo bar zoidberg farnsworth}).and_return(@buffers['leetsauce'])
      @scratches['weaksauce'].should_receive(:insert_buffer).with(%w{id foo nixon farnsworth}).and_return(@buffers['weaksauce'])
      @scratches['mayhem'].should_receive(:insert_buffer).with(%w{demolition pants shirt}).and_return(@buffers['mayhem'])
      @runner.transform
    end

    it "should add each transformed leetsauce record to the insert buffer" do
      @@data['leetsauce'].each_with_index do |record, i|
        if i == 3
          record = record.dup
          record[1] = "wee!"
        end
        @buffers['leetsauce'].should_receive(:<<).with(record)
      end
      @runner.transform
    end

    it "should add each transformed weaksauce record to the insert buffer" do
      @@data['weaksauce'].each_with_index do |record, i|
        if i != 3
          record = record.dup
          record[1] = "wee!"
        end
        @buffers['weaksauce'].should_receive(:<<).with(record)
      end
      @runner.transform
    end

    it "should add each mayhem record as-is to the insert buffer" do
      @@data['mayhem'].each do |record|
        @buffers['mayhem'].should_receive(:<<).with(record)
      end
      @runner.transform
    end

    it "should flush the insert buffers" do
      @buffers['leetsauce'].should_receive(:flush!)
      @buffers['weaksauce'].should_receive(:flush!)
      @buffers['mayhem'].should_receive(:flush!)
      @runner.transform
    end
  end
end
