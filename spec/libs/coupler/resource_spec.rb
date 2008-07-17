require File.dirname(__FILE__) + "/../../spec_helper.rb"

module ResourceHelper
  @@num = 1
  def resource_name
    @@num += 1
    "birth_#{@@num-1}"
  end

  def create_resource(spec = {})
    spec = {
      'connection' => {
        'adapter'  => 'sqlite3',
        'database' => 'db/birth.sqlite3',
        'timeout'  => 3000
      },
      'table' => {
        'name' => 'birth_all',
        'primary key' => 'ID'
      }
    }.merge(spec)
    spec['name'] ||= resource_name
    Coupler::Resource.new(spec, @options)
  end
end

shared_examples_for "any adapter" do
  describe "#set_table_and_key" do
    it "should set the table and primary key" do
      @resource.set_table_and_key('foo', 'bar')
      @resource.table.should == 'foo'
      @resource.primary_key.should == 'bar'
    end
  end

  describe "#close" do
    it "should close the connection" do
      @conn.should_receive(:close)
      @resource.close
    end
  end

  describe "#keys" do
    before(:each) do
      (1..5).inject(@query_result.stub!(:each)) { |m, i| m.and_yield([i]) }
    end

    it "should select primary key" do
      @conn.should_receive(@query_method).with("SELECT ID FROM birth_all ORDER BY ID").and_return(@query_result) 
      @resource.keys
    end

    it "should return an array of keys" do
      @resource.keys.should == [1,2,3,4,5]
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.keys
    end
  end

  describe "#multi_update" do
    it "should run: UPDATE birth_all SET foo = CASE ID ... END WHERE ID IN (...)" do
      @conn.should_receive(@query_method).with(<<EOF).and_return(@query_result)
UPDATE birth_all SET
  foo = CASE ID
    WHEN 1 THEN "bar"
    WHEN 2 THEN "baz"
  END,
  bar = CASE ID
    WHEN 1 THEN 123
    WHEN 2 THEN 456
  END
WHERE ID IN (1, 2)
EOF
      @resource.multi_update([1, 2], %w{foo bar}, [['bar', 123], ['baz', 456]])
    end

    it "should convert nils to NULLs" do
      @conn.should_receive(@query_method).with(<<EOF).and_return(@query_result)
UPDATE birth_all SET
  foo = CASE ID
    WHEN 1 THEN "bar"
    WHEN 2 THEN NULL
  END,
  bar = CASE ID
    WHEN 1 THEN NULL
    WHEN 2 THEN 456
  END
WHERE ID IN (1, 2)
EOF
      @resource.multi_update([1, 2], %w{foo bar}, [['bar', nil], [nil, 456]])
    end
  end

  describe "#update_all" do
    it "should run: UPDATE birth_all SET foo = bar" do
      @conn.should_receive(@query_method).with("UPDATE birth_all SET foo = bar").and_return(@query_result)
      @resource.update_all("foo = bar")
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.update_all("foo = bar")
    end
  end

  describe "#delete" do
    it "should run: DELETE FROM birth_all WHERE ..." do
      @conn.should_receive(@query_method).with("DELETE FROM birth_all WHERE foo = bar").and_return(@query_result)
      @resource.delete("WHERE foo = bar")
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.delete("WHERE foo = bar")
    end
  end

  describe "#insert_or_update" do
    before(:each) do
      @yes_result = stub("yes result")
      @yes_result.stub!(:next).and_return(1, nil)
      @yes_result.stub!(:execute).and_return(@yes_result)
      @no_result = stub("no result", :next => nil)
      @no_result.stub!(:execute).and_return(@no_result)
      @conn.stub!(@query_method).with("SELECT ID FROM birth_all WHERE foo = 'bar' LIMIT 1").and_return(@yes_result)
      @conn.stub!(@query_method).with("SELECT ID FROM birth_all WHERE foo = 'poo' LIMIT 1").and_return(@no_result)
      @resource.stub!(:insert)
    end

    it "should select primary key according to conditions" do
      @conn.should_receive(@query_method).with("SELECT ID FROM birth_all WHERE foo = 'bar' LIMIT 1").and_return(@yes_result)
      @resource.insert_or_update("WHERE foo = 'bar'", %w{foo bar}, [1, 2])
    end

    it "should insert if the key wasn't found" do
      @resource.should_receive(:insert).with(%w{foo bar}, [1, 2])
      @resource.insert_or_update("WHERE foo = 'poo'", %w{foo bar}, [1, 2])
    end

    it "should update if the key was found" do
      @resource.should_receive(:update).with(1, %w{foo bar}, [1, 2])
      @resource.insert_or_update("WHERE foo = 'bar'", %w{foo bar}, [1, 2])
    end
  end

  describe "#replace" do
    it "should call: REPLACE INTO birth_all (...) VALUES(...)" do
      @conn.should_receive(@query_method).with("REPLACE INTO birth_all (ID, foo) VALUES(1, \"bar\")").and_return(@query_result)
      @resource.replace(%w{ID foo}, [1, "bar"])
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.replace(%w{ID foo}, [1, "bar"])
    end
  end

  describe "#select_all" do
    it "should select * from birth_all" do
      @conn.should_receive(@query_method).with("SELECT * FROM birth_all").and_return(@query_result)
      @resource.select_all
    end

    it "should select the given fields from birth_all" do
      @conn.should_receive(@query_method).with("SELECT MomSSN, MomDOB FROM birth_all").and_return(@query_result)
      @resource.select_all("MomSSN", "MomDOB")
    end

    it "should create and return a Resource::ResultSet" do
      Coupler::Resource::ResultSet.should_receive(:new).with(@query_result, @resource.configuration['adapter']).and_return(@result_set)
      @resource.select_all.should == @result_set
    end

    it "should log its query" do
      @logger.should_receive(:debug).with("Resource (#{@resource.name}): SELECT * FROM birth_all")
      @resource.select_all
    end
  end

  describe "#select_num" do
    it "should select only a certain number of records" do
      @conn.should_receive(@query_method).with("SELECT * FROM birth_all LIMIT 10").and_return(@query_result)
      @resource.select_num(10)
    end

    it "should select the given fields from birth_all" do
      @conn.should_receive(@query_method).with("SELECT MomSSN, MomDOB FROM birth_all LIMIT 10").and_return(@query_result)
      @resource.select_num(10, "MomSSN", "MomDOB")
    end

    it "should create and return a Resource::ResultSet" do
      Coupler::Resource::ResultSet.should_receive(:new).with(@query_result, @resource.configuration['adapter']).and_return(@result_set)
      @resource.select_num(10).should == @result_set
    end

    it "should use an offset to select records" do
      @conn.should_receive(@query_method).with("SELECT * FROM birth_all LIMIT 10 OFFSET 10").and_return(@query_result)
      @resource.select_num(10, :offset => 10)
    end

    it "should log its query" do
      @logger.should_receive(:debug).with("Resource (#{@resource.name}): SELECT MomSSN, MomDOB FROM birth_all LIMIT 10")
      @resource.select_num(10, "MomSSN", "MomDOB")
    end
  end

  describe "#select_one" do
    it "should run: SELECT * FROM birth_all WHERE ID = 123" do
      @conn.should_receive(@query_method).with("SELECT * FROM birth_all WHERE ID = 123 LIMIT 1").and_return(@query_result)
      @resource.select_one(123)
    end

    it "should select the given fields for the record with id 123" do
      @conn.should_receive(@query_method).with("SELECT ID, MomSSN FROM birth_all WHERE ID = 123 LIMIT 1").and_return(@query_result)
      @resource.select_one(123, "ID", "MomSSN")
    end

    it "should create a Resource::ResultSet" do
      Coupler::Resource::ResultSet.should_receive(:new).with(@query_result, @resource.configuration['adapter']).and_return(@result_set)
      @resource.select_one(123)
    end

    it "should return the first result" do
      @result_set.stub!(:next).and_return([123])
      @resource.select_one(123).should == [123]
    end

    it "should close the result set" do
      @result_set.should_receive(:close)
      @resource.select_one(123)
    end

    it "should log its query" do
      @logger.should_receive(:debug).with("Resource (#{@resource.name}): SELECT ID, MomSSN FROM birth_all WHERE ID = 123 LIMIT 1")
      @resource.select_one(123, "ID", "MomSSN")
    end
  end

  describe "#insert" do
    it "should run: INSERT INTO birth_all (...) VALUES(...)" do
      @conn.should_receive(@query_method).with(%{INSERT INTO birth_all (ID, MomSSN) VALUES(123, "123456789")}).and_return(@query_result)
      @resource.insert(%w{ID MomSSN}, [123, "123456789"])
    end

    it "should log its query" do
      @logger.should_receive(:debug).with("Resource (#{@resource.name}): INSERT INTO birth_all (ID, MomSSN) VALUES(123, \"123456789\")")
      @resource.insert(%w{ID MomSSN}, [123, "123456789"])
    end

    it "should substitue NULL for nil" do
      @conn.should_receive(@query_method).with(%{INSERT INTO birth_all (ID, MomSSN) VALUES(123, NULL)}).and_return(@query_result)
      @resource.insert(%w{ID MomSSN}, [123, nil])
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.insert(%w{ID MomSSN}, [123, "123456789"])
    end
  end

  describe "#update" do
    it "should run: UPDATE birth_all SET ... WHERE ..." do
      @conn.should_receive(@query_method).with(%{UPDATE birth_all SET ID = 123, MomSSN = "123456789" WHERE ID = 345}).and_return(@query_result)
      @resource.update(345, %w{ID MomSSN}, [123, "123456789"])
    end

    it "should substitue NULL for nil" do
      @conn.should_receive(@query_method).with(%{UPDATE birth_all SET ID = 123, MomSSN = NULL WHERE ID = 345}).and_return(@query_result)
      @resource.update(345, %w{ID MomSSN}, [123, nil])
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.update(345, %w{ID MomSSN}, [123, "123456789"])
    end
  end

  describe "#create_table" do
    it "should run: CREATE TABLE foo (ID int, MomSSN varchar(9), PRIMARY KEY (ID))" do
      @conn.should_receive(@query_method).with(%{CREATE TABLE foo (ID int, MomSSN varchar(9), PRIMARY KEY (ID))}).and_return(@query_result)
      @resource.create_table("foo", ["ID int", "MomSSN varchar(9)"])
    end

    it "should set table attribute" do
      @resource.create_table("foo", ["ID int"])
      @resource.table.should == "foo"
    end

    it "should set primary key attribute" do
      @resource.create_table("foo", ["huge_id int"])
      @resource.primary_key.should == "huge_id"
    end

    it "should create indices on specified columns" do
      @conn.should_receive(@query_method).with(%{CREATE INDEX foo_ssn_idx ON foo (ssn)}).and_return(@query_result)
      @resource.create_table("foo", ["id int", "ssn varchar(9)", "bar datetime"], %w{ssn})
    end

    it "should create indices on multiple columns" do
      @conn.should_receive(@query_method).with(%{CREATE INDEX foo_ssn_bar_idx ON foo (ssn, bar)}).and_return(@query_result)
      @resource.create_table("foo", ["id int", "ssn varchar(9)", "bar datetime"], [%w{ssn bar}])
    end

    it "should log its query" do
      @logger.should_receive(:debug).with("Resource (#{@resource.name}): CREATE TABLE foo (id int, ssn varchar(9), bar datetime, PRIMARY KEY (id))")
      @logger.should_receive(:debug).with("Resource (#{@resource.name}): CREATE INDEX foo_ssn_idx ON foo (ssn)")
      @resource.create_table("foo", ["id int", "ssn varchar(9)", "bar datetime"], %w{ssn})
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.create_table("foo", ["ID int", "MomSSN varchar(9)"])
    end

    it "should close the query results for creating indices" do
      @query_result.should_receive(:close).twice
      @resource.create_table("foo", ["id int", "ssn varchar(9)", "bar datetime"], %w{ssn})
    end
  end

  describe "#drop_table" do
    it "should run: DROP TABLE foo" do
      @conn.should_receive(@query_method).with(%{DROP TABLE foo}).and_return(@query_result)
      @resource.drop_table("foo")
    end

    it "should catch exception it table doesn't exist" do
      @conn.stub!(:query).with(%{DROP TABLE foo}).and_raise(@error_klass)
      lambda { @resource.drop_table("foo") }.should_not raise_error
    end

    it "should log its query" do
      @logger.should_receive(:debug).with("Resource (#{@resource.name}): DROP TABLE foo")
      @resource.drop_table("foo")
    end

    it "should close the query result" do
      @query_result.should_receive(:close)
      @resource.drop_table("foo")
    end
  end

  describe "#count" do
    it "should run: SELECT COUNT(*) FROM birth_all" do
      @conn.should_receive(@query_method).with("SELECT COUNT(*) FROM birth_all").and_return(@query_result)
      @resource.count
    end

    it "should return an integer" do
      @result_set.stub!(:next).and_return([100])
      @resource.count.should == 100
    end
  end

  describe "#select" do
    it "should accept :order" do
      @conn.should_receive(@query_method).with("SELECT foo FROM birth_all ORDER BY foo").and_return(@query_result)
      @resource.select(:columns => ["foo"], :order => "foo")
    end

    it "should change * to birth_all.*" do
      @conn.should_receive(@query_method).with("SELECT ID, birth_all.* FROM birth_all").and_return(@query_result)
      @resource.select(:columns => ["ID", "*"])
    end

    describe "when refilling" do
      before(:each) do
        @refill_set = stub("refillable set")
        Coupler::Resource::RefillableSet.stub!(:new).and_return(@refill_set)
      end

      it "should create a RefillableSet and return it" do
        Coupler::Resource::RefillableSet.should_receive(:new).with(
          @resource, 10000, "SELECT birth_all.* FROM birth_all"
        ).and_return(@refill_set)
        @resource.select(:columns => ["*"], :auto_refill => true).should == @refill_set
      end

      it "should respect the --db-limit option" do
        @options.db_limit = 50000
        Coupler::Resource::RefillableSet.should_receive(:new).with(
          @resource, 50000, "SELECT birth_all.* FROM birth_all"
        ).and_return(@refill_set)
        @resource.select(:columns => ["*"], :auto_refill => true).should == @refill_set
      end
    end
  end

  describe "#columns" do
    it "should return a hash of types" do
      @resource.columns(%w{ssn dob}).should == {
        "ssn" => "varchar(9)",
        "dob" => "varchar(10)"
      }
    end
  end

  describe "#insert_buffer" do
    it "should create and return an InsertBuffer" do
      Coupler::Resource::InsertBuffer.should_receive(:new).with(@resource, 10000,
        %w{id foo bar}).and_return(@insert_buffer)
      @resource.insert_buffer(%w{id foo bar}).should == @insert_buffer
    end

    it "should respect the --db-limit options" do
      @options.db_limit = 50000
      Coupler::Resource::InsertBuffer.should_receive(:new).with(@resource, 50000,
        %w{id foo bar}).and_return(@insert_buffer)
      @resource.insert_buffer(%w{id foo bar}).should == @insert_buffer
    end
  end
end

describe Coupler::Resource do
  include ResourceHelper

  before(:each) do
    @result_set = stub("result set", :next => [], :close => nil)
    @insert_buffer = stub("insert buffer")
    @logger = stub(Logger, :info => nil, :debug => nil, :add => nil)
    @options = Coupler::Options.new
    Coupler::Resource::ResultSet.stub!(:new).and_return(@result_set)
    Coupler::Resource::InsertBuffer.stub!(:new).and_return(@insert_buffer)
    Coupler.stub!(:logger).and_return(@logger)
  end

  it "should have a name" do
    r = create_resource
    r.name.should match(/birth_\d+/) 
  end

  it "should raise an error if a resource is created with a conflicting name" do
    r = create_resource
    lambda { create_resource('name' => r.name) }.should raise_error
  end

  it "should have a connection configuration" do
    r = create_resource
    r.configuration['adapter'].should == 'sqlite3'
  end

  it "should have a primary key" do
    r = create_resource
    r.primary_key.should == "ID"
  end

  it "should not require table name and primary_key" do
    r = create_resource('table' => nil)
    r.table.should be_nil
    r.primary_key.should be_nil
  end

  describe "when connection is using sqlite3 adapter" do

    before(:each) do
      @query_method = :query
      @query_result = stub(SQLite3::ResultSet, :close => nil)
      @error_klass = SQLite3::SQLException
      @conn = stub("sqlite3 connection", :query => @query_result, :type_translation= => nil)
      @conn.stub!(:table_info).and_return([
        {"name"=>"ID", "type"=>"int", "pk"=>"1", "notnull"=>"0", "cid"=>"0", "dflt_value"=>nil},
        {"name"=>"ssn", "type"=>"varchar(9)", "pk"=>"0", "notnull"=>"0", "cid"=>"1", "dflt_value"=>nil},
        {"name"=>"dob", "type"=>"varchar(10)", "pk"=>"0", "notnull"=>"0", "cid"=>"2", "dflt_value"=>nil}
      ])
      SQLite3::Database.stub!(:new).and_return(@conn)
      @resource = create_resource
    end

    it_should_behave_like "any adapter"
    
    it "should establish a connection to the database" do
      SQLite3::Database.should_receive(:new).with('db/birth.sqlite3').and_return(@conn)
      @resource.connection.should == @conn
    end

    it "should not turn on results as hash" do
      @conn.should_not_receive(:results_as_hash=).with(true)
      @resource.connection
    end

    it "should turn on type translation" do
      @conn.should_receive(:type_translation=).with(true)
      @resource.connection
    end

    describe "#columns" do
      it "should call table_info on the adapter" do
        @conn.should_receive(:table_info).with("birth_all").and_return([
          {"name"=>"ID", "type"=>"int", "pk"=>"1", "notnull"=>"0", "cid"=>"0", "dflt_value"=>nil},
          {"name"=>"ssn", "type"=>"varchar(9)", "pk"=>"0", "notnull"=>"0", "cid"=>"1", "dflt_value"=>nil},
          {"name"=>"dob", "type"=>"varchar(10)", "pk"=>"0", "notnull"=>"0", "cid"=>"2", "dflt_value"=>nil}
        ])
        @resource.columns(%w{ssn dob})
      end
    end

    describe "#create_table" do
      it "should create table with auto increment" do
        @conn.should_receive(@query_method).with(%{CREATE TABLE foo (ID int PRIMARY KEY, MomSSN varchar(9))}).and_return(@query_result)
        @resource.create_table("foo", ["ID int", "MomSSN varchar(9)"], [], true)
      end

      it "should convert BIGINT to INT" do
        @conn.should_receive(@query_method).with(%{CREATE TABLE foo (ID int, ssn varchar(9), PRIMARY KEY (ID))}).and_return(@query_result)
        @resource.create_table("foo", ["ID bigint", "ssn varchar(9)"])
      end
    end

    describe "#replace" do
      it "should accept multiple arrays and execute a query for each" do
        @conn.should_receive(@query_method).with(
          "REPLACE INTO birth_all (ID, foo) VALUES(1, \"bar\")"
        ).and_return(@query_result)
        @conn.should_receive(@query_method).with(
          "REPLACE INTO birth_all (ID, foo) VALUES(2, \"baz\")"
        ).and_return(@query_result)
        @resource.replace(%w{ID foo}, [1, "bar"], [2, "baz"])
      end
    end

    describe "#insert" do
      it "should accept multiple arrays and execute a query for each" do
        @conn.should_receive(@query_method).with(
          "INSERT INTO birth_all (ID, foo) VALUES(1, \"bar\")"
        ).and_return(@query_result)
        @conn.should_receive(@query_method).with(
          "INSERT INTO birth_all (ID, foo) VALUES(2, \"baz\")"
        ).and_return(@query_result)
        @resource.insert(%w{ID foo}, [1, "bar"], [2, "baz"])
      end
    end

    describe "#drop_column" do
      it "should do nothing" do
        @conn.should_not_receive(@query_method)
        @resource.drop_column("foo")
      end
    end
  end

  describe "when connection is using mysql adapter" do

    before(:each) do
      @set = stub(Mysql::Result, :fetch => [])
      @query_method = :prepare
      @query_result = stub(Mysql::Stmt, :close => nil)
      @query_result.stub!(:execute).and_return(@query_result)
      @error_klass = Mysql::Error
      @conn = stub("mysql connection", :prepare => @query_result, :query => @set)
      Mysql.stub!(:new).and_return(@conn)
      @resource = create_resource({
        'connection' => {
          'adapter'  => 'mysql',
          'host'     => 'localhost',
          'username' => 'viking',
          'password' => 'pillage',
          'database' => 'foo'
        }
      })

      # for describe
      @query_result.stub!(:fetch).and_return(
        ["ssn", "varchar(9)", "YES", "", nil, ""],
        ["dob", "varchar(10)", "YES", "", nil, ""],
        nil
      )
    end
    
    it_should_behave_like "any adapter"

    it "should establish a connection to the database" do
      Mysql.should_receive(:new).with("localhost", "viking", "pillage", "foo").and_return(@conn)
      @resource.connection.should == @conn
    end

    describe "#replace" do
      it "should accept multiple arrays and execute one query" do
        @conn.should_receive(@query_method).with(
          "REPLACE INTO birth_all (ID, foo) VALUES(1, \"bar\"), (2, \"baz\")"
        ).and_return(@query_result)
        @resource.replace(%w{ID foo}, [1, "bar"], [2, "baz"])
      end
    end

    describe "#insert" do
      it "should accept multiple arrays and execute one query" do
        @conn.should_receive(@query_method).with(
          "INSERT INTO birth_all (ID, foo) VALUES(1, \"bar\"), (2, \"baz\")"
        ).and_return(@query_result)
        @resource.insert(%w{ID foo}, [1, "bar"], [2, "baz"])
      end
    end

    describe "#select_all" do
      it "should execute the statement" do
        @query_result.should_receive(:execute)
        @resource.select_all
      end
    end

    describe "#columns" do
      it "should run: SHOW FIELDS FROM birth_all WHERE Field IN ('ssn', 'dob')" do
        @conn.should_receive(@query_method).with("SHOW FIELDS FROM birth_all WHERE Field IN (\"ssn\", \"dob\")").and_return(@query_result)
        @resource.columns(%w{ssn dob})
      end
      
      it "should log its query" do
        @logger.should_receive(:debug).with("Resource (#{@resource.name}): SHOW FIELDS FROM birth_all WHERE Field IN (\"ssn\", \"dob\")")
        @resource.columns(%w{ssn dob})
      end

      it "should close the query result" do
        @query_result.should_receive(:close)
        @resource.columns(%w{ssn dob})
      end
    end

    describe "#create_table" do
      it "should create table with auto increment" do
        @conn.should_receive(@query_method).with(%{CREATE TABLE foo (ID int NOT NULL AUTO_INCREMENT, MomSSN varchar(9), PRIMARY KEY (ID))}).and_return(@query_result)
        @resource.create_table("foo", ["ID int", "MomSSN varchar(9)"], [], true)
      end
    end

    describe "#drop_column" do
      it "should call: ALTER TABLE birth_all DROP COLUMN foo" do
        @conn.should_receive(@query_method).with(%{ALTER TABLE birth_all DROP COLUMN foo}).and_return(@query_result)
        @resource.drop_column("foo")
      end
    end
  end

  describe ".find" do
    it "should find previously created resources by name" do
      r = create_resource
      Coupler::Resource.find(r.name).should == r
    end
  end
  
  describe ".reset" do
    it "should remove all resources" do
      r1 = create_resource
      r2 = create_resource
      Coupler::Resource.reset
      Coupler::Resource.find(r1.name).should be_nil
      Coupler::Resource.find(r2.name).should be_nil
    end
  end

end

describe Coupler::Resource::ResultSet do
  describe "when initialized with a mysql result set" do
    before(:each) do
      @query_result = stub(Mysql::Result, :close => nil)
      @result_type  = 'mysql'
    end

    describe do
      before(:each) do
        @result_set = Coupler::Resource::ResultSet.new(@query_result, @result_type)
      end

      describe "#each" do
        it "should iterate over each" do
          block = Proc.new { "foo" }
          @query_result.should_receive(:each).with(&block)
          @result_set.each(&block)
        end
      end

      describe "#next" do
        it "should call fetch" do
          @query_result.should_receive(:fetch).and_return([])
          @result_set.next
        end
      end

      describe "#close" do
        it "should call close" do
          @query_result.should_receive(:close)
          @result_set.close
        end

        it "should not close again" do
          @result_set.close
          @query_result.should_not_receive(:close)
          @result_set.close
        end
      end
    end
  end

  describe "when initialized with a sqlite3 result set" do
    before(:each) do
      @query_result = stub(SQLite3::ResultSet, :each => nil, :next => {}, :close => nil)
      @result_type  = 'sqlite3'
    end

    describe do
      before(:each) do
        @result_set = Coupler::Resource::ResultSet.new(@query_result, @result_type)
      end

      describe "#each" do
        it "should iterate over each" do
          block = Proc.new { "foo" }
          @query_result.should_receive(:each).with(&block)
          @result_set.each(&block)
        end
      end

      describe "#next" do
        it "should call next" do
          @query_result.should_receive(:next).and_return({})
          @result_set.next
        end
      end

      describe "#close" do
        it "should call close" do
          @query_result.should_receive(:close)
          @result_set.close
        end

        it "should not close again" do
          @result_set.close
          @query_result.should_not_receive(:close)
          @result_set.close
        end
      end
    end
  end
end

shared_examples_for "a refillable set with any adapter" do
  describe "#next" do
    it "should run the query the first time it's called" do
      @resource.should_receive(:run_and_log_query).with("SELECT * FROM foo LIMIT 10000 OFFSET 0").and_return(@query_result)
      @set.next
    end

    it "should fetch the next item and return it" do
      @query_result.should_receive(@next_method).and_return(["blah"])
      @set.next.should == ["blah"]
    end

    describe "when it's time to refill" do
      before(:each) do
        @query_result.stub!(@next_method).and_return(nil, ["blargh"])
      end

      it "should close the query result" do
        @query_result.should_receive(:close)
        @set.next
      end

      it "should query the database again, adjusting the offset accordingly" do
        @resource.should_receive(:run_and_log_query).with("SELECT * FROM foo LIMIT 10000 OFFSET 10000").and_return(@query_result)
        @set.next
      end

      it "should fetch the next record after re-filling and return it" do
        @query_result.should_receive(@next_method).twice.and_return(nil, ["blargh"])
        @set.next
      end

    end

    describe "when there are no more records to fetch" do
      before(:each) do
        @query_result.stub!(@next_method).and_return(nil, nil)
      end

      it "should not attempt anymore refills" do
        @set.next

        @resource.should_not_receive(:run_and_log_query).and_return(@query_result)
        @set.next.should be_nil
      end

      it "should close itself" do
        @query_result.should_receive(:close).twice
        @set.next
      end
    end
  end
end

describe Coupler::Resource::RefillableSet do
  before(:each) do
    @query_result = stub("query result", :close => nil)
    @resource = stub("parent resource", :adapter => 'mysql', :run_and_log_query => @query_result)
  end

  def create_set(parent, page_size, query)
    Coupler::Resource::RefillableSet.new(parent, page_size, query)
  end

  it "should have a superclass of ResultSet" do
    Coupler::Resource::RefillableSet.superclass.should == Coupler::Resource::ResultSet
  end

  it "should have a parent resource" do
    set = create_set(@resource, 10000, "SELECT * FROM foo")
    set.parent.should == @resource
  end

  it "should have a page size of 10000" do
    set = create_set(@resource, 10000, "SELECT * FROM foo")
    set.page_size.should == 10000
  end

  it "should have a query" do
    set = create_set(@resource, 10000, "SELECT * FROM foo")
    set.query.should == "SELECT * FROM foo"
  end

  it "should have a type" do
    set = create_set(@resource, 10000, "SELECT * FROM foo")
    set.type.should == 'mysql'
  end

  describe "when adapter is 'mysql'" do
    before(:each) do
      @next_method = :fetch
      @set = create_set(@resource, 10000, "SELECT * FROM foo")
      @query_result.stub!(@next_method).and_return(["blah"])
    end

    it_should_behave_like "a refillable set with any adapter"
  end

  describe "when adapter is 'sqlite3'" do
    before(:each) do
      @next_method = :next
      @resource.stub!(:adapter).and_return('sqlite3')
      @set = create_set(@resource, 10000, "SELECT * FROM foo")
      @query_result.stub!(@next_method).and_return(["blah"])
    end

    it_should_behave_like "a refillable set with any adapter"
  end
end

describe Coupler::Resource::InsertBuffer do
  before(:each) do
    @resource = stub("parent resource", :adapter => 'mysql', :insert => nil)
    @buffer   = stub(Buffer, :full? => false, :empty? => false, :data => ["blah"], :flush! => nil)
    @buffer.stub!(:<<).and_return(@buffer)
    Buffer.stub!(:new).and_return(@buffer)
  end

  def create_buffer(parent, page_size, columns)
    Coupler::Resource::InsertBuffer.new(parent, page_size, columns)
  end

  it "should create a Buffer object" do
    Buffer.should_receive(:new).with(100).and_return(@buffer)
    create_buffer(@resource, 100, %w{id foo bar})
  end

  describe "#<<" do
    before(:each) do
      @insert_buffer = create_buffer(@resource, 5, %w{id foo bar})
    end

    it "should call Buffer#<<" do
      @buffer.should_receive(:<<).with([1, 2, 3]).and_return(@buffer)
      @insert_buffer << [1, 2, 3]
    end

    describe "when buffer is full" do
      before(:each) do
        @records = [[1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6], [5, 6, 7]]
        @buffer.stub!(:data).and_return(@records)
        @buffer.stub!(:full?).and_return(true)
      end

      it "should perform an insert, then flush the buffer" do
        @resource.should_receive(:insert).with(%w{id foo bar}, *@records).ordered
        @buffer.should_receive(:flush!).ordered
        @insert_buffer << [6, 7, 8]
      end
    end
  end

  describe "#flush!" do
    before(:each) do
      @insert_buffer = create_buffer(@resource, 5, %w{id foo bar})
      @records = [[1, 2, 3], [2, 3, 4], [3, 4, 5], [4, 5, 6], [5, 6, 7]]
      @buffer.stub!(:data).and_return(@records)
      @buffer.stub!(:empty?).and_return(false)
    end

    it "should perform an insert, then flush the buffer" do
      @resource.should_receive(:insert).with(%w{id foo bar}, *@records).ordered
      @buffer.should_receive(:flush!).ordered
      @insert_buffer.flush!
    end

    it "should not do anything if the buffer is empty" do
      @buffer.stub!(:empty?).and_return(true)
      @resource.should_not_receive(:insert)
      @buffer.should_not_receive(:flush!)
      @insert_buffer.flush!
    end
  end
end
