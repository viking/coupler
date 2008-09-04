require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformer::Base do
  Base = Coupler::Transformer::Base

  it "should have a sql_template class accessor" do
    Base.should respond_to(:sql_template)
    Base.sql_template = "huge"
    Base.sql_template.should == "huge"
  end

  it "should have a ruby_template class accessor" do
    Base.should respond_to(:ruby_template)
    Base.ruby_template = "huge"
    Base.ruby_template.should == "huge"
  end

  it "should have a type_template class accessor" do
    Base.should respond_to(:type_template)
    Base.type_template = "huge"
    Base.type_template.should == "huge"
  end

  it "should have a parameters class accessor" do
    Base.should respond_to(:parameters)
    Base.parameters = %w{huge}
    Base.parameters.should == %w{huge}
  end

  describe "a subclass" do
    before(:each) do
      @klass = Class.new(Coupler::Transformer::Base)
      @field_list = %w{id dude bar junk argh}
      @klass.class_eval do
        @parameters    = %w{foo blah}
        @sql_template  = "foo * blah"
        @ruby_template = "foo * blah"
        @type_template = "same as foo"
      end
    end

    def create_instance(options = {})
      options = {
        'field' => 'blargh',
        'arguments' => {
          'foo'  => 'bar',
          'blah' => 'junk'
        }
      }.merge(options)
      @klass.new(options)
    end

    it "should have a field" do
      create_instance.field.should == 'blargh'
    end

    it "should have arguments" do
      create_instance.arguments.should == {'foo' => 'bar', 'blah' => 'junk'}
    end

    it "should have a field_list writer" do
      (create_instance.field_list = @field_list).should == @field_list
    end

    describe "#sql" do
      it "should return a sql string" do
        create_instance.sql.should == "(bar * junk) AS blargh"
      end

      it "should return a mysql-specific string if available" do
        @klass.sql_template = {'mysql' => "foo / blah"}
        create_instance.sql('mysql').should == "(bar / junk) AS blargh"
      end

      it "should return the default string if the sql_template is not a hash" do
        create_instance.sql('mysql').should == "(bar * junk) AS blargh"
      end

      it "should return nil the sql_template is a hash and the key doesn't exist" do
        @klass.sql_template = {'mysql' => "foo / blah"}
        create_instance.sql('sqlite3').should be_nil
      end

      it "should use the default formula if sql_template is a hash and the given key doesn't exist" do
        @klass.sql_template = {'default' => "foo / blah"}
        create_instance.sql('mysql').should == "(bar / junk) AS blargh"
      end
    end

    describe "#transform" do
      before(:each) do
        @inst = create_instance
        @inst.field_list = @field_list
      end

      it "should complain if there is no field_list" do
        @inst.field_list = nil
        lambda { @inst.transform([1, "dude", "ya", 5, 123]) }.should raise_error("assign field_list first")
      end

      it "should return the result of the formula" do
        @inst.transform([1, "dude", "ya", 5, 123]).should == "yayayayaya"
        @inst.transform([1, "x", "_.-.", 3, 1337]).should == "_.-._.-._.-."
      end
    end

    it "#has_sql? should be true" do
      create_instance.should have_sql
    end

    it "#has_sql? should be false if there is no template" do
      @klass.sql_template = nil
      create_instance.should_not have_sql
    end

    describe "#sql_type" do
      it "should substitute arguments for parameters" do
        create_instance.sql_type.should == "same as bar"
      end

      it "should pass static type through untouched" do
        @klass.type_template = "int(11)"
        create_instance.sql_type.should == "int(11)"
      end
    end
  end
end
