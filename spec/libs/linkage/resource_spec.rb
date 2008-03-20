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
    @resource = create_resource 
  end

  it "should have a name" do
    @resource.name.should match(/birth_\d+/) 
  end

  it "should raise an error if a resource is created with a conflicting name" do
    lambda { create_resource('name' => @resource.name) }.should raise_error
  end

  it "should setup an AR connection to a database" do
    ActiveRecord::Base.configurations[@resource.name]['adapter'].should == 'sqlite3'
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

  it "should create a record class for the table" do
    @resource.record.should be_an_instance_of(Class)
  end

  describe "the record class" do
    before(:each) do
      @klass = @resource.record
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

    it "should have a primary_key of 'ID'" do
      @klass.primary_key.should == 'ID'
    end
  end

  describe ".find" do
    it "should find previously created resources by name" do
      Linkage::Resource.find(@resource.name).should == @resource
    end
  end
end
