steps_for(:transformer) do
  FIXDIR = File.expand_path(File.dirname(__FILE__) + "/../fixtures")

  Given "the $name specification" do |name|
    logger = Logger.new("log/story.log")
    logger.level = Logger::DEBUG
    Coupler.logger = logger

    Coupler::Resource.reset
    Coupler::Transformer.reset

    @options  = Coupler::Options.new
    @spec_raw = File.read(File.join(FIXDIR, "#{name}.yml.erb"))
  end

  Given "that I want to use the $adapter adapter" do |adapter|
    @spec = YAML.load(Erubis::Eruby.new(@spec_raw).result(binding))
  end

  Given "the option of using an existing scratch database" do
    @options.use_existing_scratch = true
  end

  When "I transform the resources" do
    Coupler::Runner.transform(@spec, @options)
  end

  Then "there should be a scratch table named $table with primary key $key" do |table, key|
    @table    = table
    @key      = key
    @scratch  = Coupler::Resource.find('scratch')
    @scratch.set_table_and_key(table, key)
    lambda { @scratch.select(:first, :columns => [key]) }.should_not raise_error
  end

  Then "it should have column: $name $type" do |name, type|
    info = @scratch.columns([name])
    info[name][0, type.length].should == type
  end

  Then "$field should have been transformed properly" do |field|
    resource = Coupler::Resource.find(@table)
    columns  = field == 'foo' ? [@key, 'foo'] : [@key, 'zoidberg', 'nixon']
    orig = resource.select(:all, :columns => columns, :order => @key)
    curr = @scratch.select(:all, :columns => [@key, field], :order => @key)
    while (o_row = orig.next)
      c_row = curr.next

      case field
      when 'foo'
        o_foo = o_row[1]; c_foo = c_row[1]
        if o_foo =~ /^(\d)\1{8}$/
          then c_foo.should be_nil
          else c_foo.should == o_foo
        end
      when 'bar'
        o_zoid, o_nix = o_row[1, 2]; c_bar = c_row[1]
        if o_zoid < 10
          then c_bar.should == o_nix * 10
          else c_bar.should == o_zoid / 5 
        end
      end
    end
  end

  Then "$field should not have been transformed" do |field|
    resource = Coupler::Resource.find(@table)
    orig = resource.select(:all, :columns => [@key, field], :order => @key)
    curr = @scratch.select(:all, :columns => [@key, field], :order => @key)
    while (o_row = orig.next)
      c_row = curr.next
      c_row.should == o_row
    end
  end
end
