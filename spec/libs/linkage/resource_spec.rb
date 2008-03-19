require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Resource do

  describe "when creating" do
    before(:each) do 
      @copts = { 'adapter' => 'sqlite3', 'database' => 'db/birth.sqlite3', 'timeout' => 3000 }
      @opts  = { 
        'name' => 'birth',
        'connection' => @copts,
        'tables' => %w{birth_all}
      }
      @resource = Linkage::Resource.new(@opts)
    end

    it "should have a name" do
      @resource.name.should == 'birth'
    end

    it "should treat its options hash indifferently" do
      @opts[:name] = @opts.delete('name')
      resource = Linkage::Resource.new(@opts)
      resource.name.should == 'birth'
    end

    it "should setup an AR connection to a database" do
      ActiveRecord::Base.configurations['birth'].should == @copts
    end

    it "should create an abstract base class" do
      @resource.abstract_base.should be_an_instance_of(Class)
    end

    describe "the abstract base class" do
      before(:each) do
        @klass = @resource.abstract_base
      end

      it "should have a name" do
        @klass.name.should match(/Linkage::Resource::AbstractBase_\d+/)
      end

      it "should have a superclass of ActiveRecord::Base" do
        @klass.superclass.should == ActiveRecord::Base
      end

      it "should be an abstract class" do
        @klass.should be_an_abstract_class
      end

      it "should have an established connection" do
        @klass.connection.should_not be_nil
      end
    end

    it "should have a hash of records" do
      @resource.records.should be_an_instance_of(HashWithIndifferentAccess)
    end

    it "should create an record class for a table" do
      @resource.records['birth_all'].should be_an_instance_of(Class)
    end

    describe "a record class" do
      before(:each) do
        @klass = @resource.records['birth_all']
      end

      it "should have a name" do
        @klass.name.should match(/#{@resource.abstract_base.name}::Table_\d+/)
      end

      it "should have a superclass of the abstract base class" do
        @klass.superclass.should == @resource.abstract_base
      end

      it "should have a table_name of 'birth_all'" do
        @klass.table_name.should == 'birth_all'
      end
    end
  end
end
