require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Resource do

  @@num = 1
  def resource_name
    @@num += 1
    "birth_#{@@num-1}"
  end

  def create_resource(options = {})
    options = {
      'connection' => {
        'adapter'  => 'sqlite3',
        'database' => 'db/birth.sqlite3',
        'timeout'  => 3000
      },
      'table' => {
        'name' => 'birth_all',
        'primary_key' => 'ID'
      }
    }.merge(options)
    options['name'] ||= resource_name
    Linkage::Resource.new(options)
  end

  before(:each) do
    @result = stub("result set", :next => [], :close => nil)
    @logger = stub(Logger, :info => nil, :debug => nil, :add => nil)
    Linkage::Resource::ResultSet.stub!(:new).and_return(@result)
    Linkage.stub!(:logger).and_return(@logger)
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
      @set  = stub(SQLite3::ResultSet)
      @conn = stub("sqlite3 connection", :query => @set, :type_translation= => nil)
      SQLite3::Database.stub!(:new).and_return(@conn)
      @resource = create_resource
    end
    
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

    describe "#select_all" do
      it "should select * from birth_all" do
        @conn.should_receive(:query).with("SELECT * FROM birth_all").and_return(@result)
        @resource.select_all
      end

      it "should select the given fields from birth_all" do
        @conn.should_receive(:query).with("SELECT MomSSN, MomDOB FROM birth_all").and_return(@result)
        @resource.select_all("MomSSN", "MomDOB")
      end

      it "should create and return a Resource::ResultSet" do
        Linkage::Resource::ResultSet.should_receive(:new).with(@set, @resource.configuration['adapter']).and_return(@result)
        @resource.select_all.should == @result
      end

      it "should log its query" do
        @logger.should_receive(:debug).with("Resource (#{@resource.name}): SELECT * FROM birth_all")
        @resource.select_all
      end
    end

    describe "select_num" do
      it "should select only a certain number of records" do
        @conn.should_receive(:query).with("SELECT * FROM birth_all LIMIT 10").and_return(@set)
        @resource.select_num(10)
      end

      it "should select the given fields from birth_all" do
        @conn.should_receive(:query).with("SELECT MomSSN, MomDOB FROM birth_all LIMIT 10").and_return(@result)
        @resource.select_num(10, "MomSSN", "MomDOB")
      end

      it "should create and return a Resource::ResultSet" do
        Linkage::Resource::ResultSet.should_receive(:new).with(@set, @resource.configuration['adapter']).and_return(@result)
        @resource.select_num(10).should == @result
      end

      it "should use an offset to select records" do
        @conn.should_receive(:query).with("SELECT * FROM birth_all LIMIT 10 OFFSET 10").and_return(@result)
        @resource.select_num(10, :offset => 10)
      end
    end

    describe "#select_one" do
      it "should run: SELECT * FROM birth_all WHERE ID = 123" do
        @conn.should_receive(:query).with("SELECT * FROM birth_all WHERE ID = 123 LIMIT 1").and_return(@set)
        @resource.select_one(123)
      end

      it "should select the given fields for the record with id 123" do
        @conn.should_receive(:query).with("SELECT ID, MomSSN FROM birth_all WHERE ID = 123 LIMIT 1").and_return(@set)
        @resource.select_one(123, "ID", "MomSSN")
      end

      it "should create a Resource::ResultSet" do
        Linkage::Resource::ResultSet.should_receive(:new).with(@set, @resource.configuration['adapter']).and_return(@result)
        @resource.select_one(123)
      end

      it "should return the first result" do
        @result.stub!(:next).and_return([123])
        @resource.select_one(123).should == [123]
      end

      it "should close the result set" do
        @result.should_receive(:close)
        @resource.select_one(123)
      end
    end

    describe "#insert" do
      it "should run: INSERT INTO birth_all (...) VALUES(...)" do
        @conn.should_receive(:query).with(%{INSERT INTO birth_all (ID, MomSSN) VALUES(123, "123456789")})
        @resource.insert(%w{ID MomSSN}, [123, "123456789"])
      end
    end

    describe "#create_table" do
      it "should run: CREATE TABLE foo (ID int, MomSSN varchar(9), PRIMARY KEY (ID))" do
        @conn.should_receive(:query).with(%{CREATE TABLE foo (ID int, MomSSN varchar(9), PRIMARY KEY (ID))})
        @resource.create_table("foo", "ID int", "MomSSN varchar(9)")
      end

      it "should set table attribute" do
        @resource.create_table("foo", "ID int")
        @resource.table.should == "foo"
      end

      it "should set primary key attribute" do
        @resource.create_table("foo", "huge_id int")
        @resource.primary_key.should == "huge_id"
      end
    end

    describe "#drop_table" do
      it "should run: DROP TABLE foo" do
        @conn.should_receive(:query).with(%{DROP TABLE foo})
        @resource.drop_table("foo")
      end

      it "should catch exception it table doesn't exist" do
        @conn.stub!(:query).with(%{DROP TABLE foo}).and_raise(SQLite3::SQLException)
        lambda { @resource.drop_table("foo") }.should_not raise_error
      end
    end

    describe "#count" do
      it "should run: SELECT COUNT(*) FROM birth_all" do
        @conn.should_receive(:query).with("SELECT COUNT(*) FROM birth_all")
        @resource.count
      end

      it "should return an integer" do
        @result.stub!(:next).and_return([100])
        @resource.count.should == 100
      end
    end
  end

  describe "when connection is using mysql adapter" do

    before(:each) do
      @set  = stub(Mysql::Result)
      @stmt = stub(Mysql::Stmt)
      @stmt.stub!(:execute).and_return(@stmt)
      @conn = stub("mysql connection", :prepare => @stmt, :query => @set)
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
    end
    
    it "should establish a connection to the database" do
      Mysql.should_receive(:new).with("localhost", "viking", "pillage", "foo").and_return(@conn)
      @resource.connection.should == @conn
    end
    
    describe "#select_all" do
      it "should prepare: SELECT * FROM birth_all" do
        @conn.should_receive(:prepare).with("SELECT * FROM birth_all").and_return(@stmt)
        @resource.select_all
      end

      it "should execute the statement" do
        @stmt.should_receive(:execute)
        @resource.select_all
      end

      it "should prepare to select the given fields from birth_all" do
        @conn.should_receive(:prepare).with("SELECT MomSSN, MomDOB FROM birth_all").and_return(@stmt)
        @resource.select_all("MomSSN", "MomDOB")
      end

      it "should create and return a Resource::ResultSet" do
        Linkage::Resource::ResultSet.should_receive(:new).with(@stmt, @resource.configuration['adapter']).and_return(@result)
        @resource.select_all.should == @result
      end
    end

    describe "#select_one" do
      it "should prepare: SELECT * FROM birth_all WHERE ID = 123" do
        @conn.should_receive(:prepare).with("SELECT * FROM birth_all WHERE ID = 123 LIMIT 1").and_return(@stmt)
        @resource.select_one(123)
      end

      it "should select the given fields for the record with id 123" do
        @conn.should_receive(:prepare).with("SELECT ID, MomSSN FROM birth_all WHERE ID = 123 LIMIT 1").and_return(@stmt)
        @resource.select_one(123, "ID", "MomSSN")
      end

      it "should create a Resource::ResultSet" do
        Linkage::Resource::ResultSet.should_receive(:new).with(@stmt, @resource.configuration['adapter']).and_return(@result)
        @resource.select_one(123)
      end

      it "should return the first result" do
        @result.stub!(:next).and_return([123])
        @resource.select_one(123).should == [123]
      end

      it "should close the result set" do
        @result.should_receive(:close)
        @resource.select_one(123)
      end
    end

    describe "#select_num" do
      it "should select only a certain number of records" do
        @conn.should_receive(:prepare).with("SELECT * FROM birth_all LIMIT 10").and_return(@stmt)
        @resource.select_num(10)
      end

      it "should select the given fields from birth_all" do
        @conn.should_receive(:prepare).with("SELECT MomSSN, MomDOB FROM birth_all LIMIT 10").and_return(@stmt)
        @resource.select_num(10, "MomSSN", "MomDOB")
      end

      it "should create and return a Resource::ResultSet" do
        Linkage::Resource::ResultSet.should_receive(:new).with(@stmt, @resource.configuration['adapter']).and_return(@result)
        @resource.select_num(10).should == @result
      end

      it "should use an offset to select records" do
        @conn.should_receive(:prepare).with("SELECT * FROM birth_all LIMIT 10 OFFSET 10").and_return(@stmt)
        @resource.select_num(10, :offset => 10)
      end
    end

    describe "#insert" do
      it "should run: INSERT INTO birth_all (...) VALUES(...)" do
        @conn.should_receive(:query).with(%{INSERT INTO birth_all (ID, MomSSN) VALUES(123, "123456789")})
        @resource.insert(%w{ID MomSSN}, [123, "123456789"])
      end
    end

    describe "#create_table" do
      it "should run: CREATE TABLE foo (ID int, MomSSN varchar(9), PRIMARY KEY (ID))" do
        @conn.should_receive(:query).with(%{CREATE TABLE foo (ID int, MomSSN varchar(9), PRIMARY KEY (ID))})
        @resource.create_table("foo", "ID int", "MomSSN varchar(9)")
      end

      it "should set table attribute" do
        @resource.create_table("foo", "ID int")
        @resource.table.should == "foo"
      end

      it "should set primary key attribute" do
        @resource.create_table("foo", "huge_id int")
        @resource.primary_key.should == "huge_id"
      end
    end

    describe "#count" do
      it "should run: SELECT COUNT(*) FROM birth_all" do
        @conn.should_receive(:prepare).with("SELECT COUNT(*) FROM birth_all").and_return(@stmt)
        @resource.count
      end

      it "should return an integer" do
        @result.stub!(:next).and_return([100])
        @resource.count.should == 100
      end
    end

    describe "#drop_table" do
      it "should run: DROP TABLE foo" do
        @conn.should_receive(:query).with(%{DROP TABLE foo})
        @resource.drop_table("foo")
      end

      it "should catch exception it table doesn't exist" do
        @conn.stub!(:query).with(%{DROP TABLE foo}).and_raise(Mysql::Error)
        lambda { @resource.drop_table("foo") }.should_not raise_error
      end
    end
  end

  describe ".find" do
    it "should find previously created resources by name" do
      r = create_resource
      Linkage::Resource.find(r.name).should == r
    end
  end
end

describe Linkage::Resource::ResultSet do
  describe "when initialized with a mysql result set" do
    before(:each) do
      @mysql = stub(Mysql::Result)
      @result_set = Linkage::Resource::ResultSet.new(@mysql, 'mysql')
    end

    describe "#each" do
      it "should iterate over each" do
        block = Proc.new { "foo" }
        @mysql.should_receive(:each).with(&block)
        @result_set.each(&block)
      end
    end

    describe "#next" do
      it "should call fetch" do
        @mysql.should_receive(:fetch).and_return([])
        @result_set.next
      end
    end

    describe "#close" do
      it "should call close" do
        @mysql.should_receive(:close)
        @result_set.close
      end
    end
  end

  describe "when initialized with a sqlite3 result set" do
    before(:each) do
      @sqlite3 = stub(SQLite3::ResultSet, :each => nil, :next => {})
      @result_set = Linkage::Resource::ResultSet.new(@sqlite3, 'sqlite3')
    end

    describe "#each" do
      it "should iterate over each" do
        block = Proc.new { "foo" }
        @sqlite3.should_receive(:each).with(&block)
        @result_set.each(&block)
      end
    end

    describe "#next" do
      it "should call next" do
        @sqlite3.should_receive(:next).and_return({})
        @result_set.next
      end
    end

    describe "#close" do
      it "should call close" do
        @sqlite3.should_receive(:close)
        @result_set.close
      end
    end
  end
end
