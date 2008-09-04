steps_for(:transformer) do

  Then "there should be a scratch table named $table with primary key $key" do |table, key|
    @table    = table
    @key      = key
    @scratch  = Coupler::Resource.find("#{table}_scratch")
    @scratch.close    # sqlite3 bitches about schema changes sometimes
    lambda { @scratch.select(:first, :columns => [key]) }.should_not raise_error
  end

  Then "it should have column: $name $type" do |name, type|
    info = @scratch.columns([name])
    info[name][0, type.length].should == type
  end

  Then "foo should have been transformed properly" do
    resource = Coupler::Resource.find(@table)
    columns  = @table == 'leetsauce' ? [@key, 'foo'] : [@key, 'wicked']
    orig = resource.select(:all, :columns => columns, :order => @key)
    curr = @scratch.select(:all, :columns => [@key, 'foo'], :order => @key)
    while (o_row = orig.next)
      c_row = curr.next
      o_foo = o_row[1]; c_foo = c_row[1]
      if o_foo =~ /^(\d)\1{8}$/
        then c_foo.should be_nil
        else c_foo.should == o_foo
      end
    end
  end

  Then "bar should have been transformed properly" do
    resource = Coupler::Resource.find(@table)
    columns  = [@key, 'zoidberg', 'nixon']
    orig = resource.select(:all, :columns => columns, :order => @key)
    curr = @scratch.select(:all, :columns => [@key, 'bar'], :order => @key)
    while (o_row = orig.next)
      c_row = curr.next
      o_zoid, o_nix = o_row[1, 2]; c_bar = c_row[1]
#      begin
        if o_zoid < 10
          then c_bar.should == o_nix * 10
          else c_bar.should == o_zoid / 5
#          raise if c_bar != o_nix * 10
#        else
#          raise if c_bar != o_zoid / 5
#        end
#      rescue
#        debugger
#        p o_zoid, o_nix, c_bar
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

  Then "$field should have been renamed to $rfield" do |field, rfield|
    resource = Coupler::Resource.find(@table)
    orig = resource.select(:all, :columns => [@key, field],  :order => @key)
    curr = @scratch.select(:all, :columns => [@key, rfield], :order => @key)
    while (o_row = orig.next)
      c_row = curr.next
      c_row.should == o_row
    end
  end
end
