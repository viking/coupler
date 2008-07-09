steps_for(:transformer) do
  Given "the $name specification" do |name|
    fn = File.join(File.dirname(__FILE__), "files", "#{name}.yml")
    @options = Coupler::Options.new
    @options.filenames << fn

    Coupler::Resource.reset
    Coupler::Transformer.reset
    @adapter = name
    @results = Hash.new { |h, k| h[k] = {} }
    @matched = Hash.new { |h, k| h[k] = [] }

    logger       = Logger.new("log/story.log")
    logger.level = Logger::DEBUG
    Coupler.logger = logger
  end

  Given "the option of using an existing scratch database" do
    @options.use_existing_scratch = true
  end

  When "I transform the resources" do
    Coupler::Runner.transform(@options)
  end

  Then "there should be a table named $table with primary key $key" do |table, key|
    @scratch = Coupler::Resource.find('scratch')
    @scratch.set_table_and_key(table, key)
    lambda { @scratch.select(:first, :columns => ["ID"]) }.should_not raise_error
  end

  Then "it should have column: $name $type" do |name, type|
    info = @scratch.columns([name])
    info[name].should == type
  end

  Then "every $nth $field should be NULL" do |nth, field|
    n = nth.sub(/th$/, "").to_i
    res = @scratch.select(:all, :columns => [field], :order => @scratch.primary_key)
    i = 0
    while (row = res.next)
      row[0].should(be_nil)   if i % n == 0
      i += 1
    end
  end

  Then "every dob should have 10 days added" do
    res = @scratch.select(:all, :columns => %w{dob}, :order => @scratch.primary_key)
    i = 0
    while (row = res.next)
      if i % 75 == 0
        row[0].should be_nil
      else
        expected = (Date.parse("1970-01-%02d" % (i % 25 + 1)) + 10).to_s
        row[0].should == expected 
      end
      i += 1
    end
  end

  Then "every foo should be multiplied by 10" do
    res = @scratch.select(:all, :columns => %w{foo}, :order => @scratch.primary_key)
    i = 0
    while (row = res.next)
      i += 1
      row[0].should == i * 10
    end
  end

  Then "every bar should be multiplied by 5" do
    res = @scratch.select(:all, :columns => %w{bar}, :order => @scratch.primary_key)
    i = 0
    while (row = res.next)
      i += 1
      row[0].should == -i * 5
    end
  end
end
