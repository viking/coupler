require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformer::Custom do
  Custom = Coupler::Transformer::Custom

  describe "#build" do
    def do_build(opts = {})
      options = {
        'name' => 'bar_bender',
        'parameters' => %w{fry leela},
        'ruby' => "fry < 10 ? leela * 10 : fry / 5",
        'sql'  => "IF(fry < 10, leela * 10, fry / 5)",
        'type' => 'int(11)',
      }.merge(opts)
      Custom.build(options)
    end

    it "should add a new class to its function list" do
      do_build.should be_an_instance_of(Class)
    end

    describe "the class" do
      before(:each) do
        @klass = do_build
      end

      it "should be a subclass of Base" do
        @klass.superclass.should == Coupler::Transformer::Base
      end

      it "should have parameters" do
        @klass.parameters.should == %w{fry leela}
      end

      # I probably don't need to expose these
      it "should have a sql_template" do
        @klass.sql_template.should == "IF(fry < 10, leela * 10, fry / 5)"
      end

      it "should have a ruby_template" do
        @klass.ruby_template.should == "fry < 10 ? leela * 10 : fry / 5"
      end

      it "should have a type_template" do
        @klass.type_template.should == "int(11)"
      end

      describe "an instance" do
        before(:each) do
          @transformer = @klass.new({
            "field" => 'bar',
            "function" => "bar_bender",
            "arguments" => {
              'fry' => 'zoidberg',
              'leela' => 'nixon',
            }
          })
        end

        it "#sql should return the correct string" do
          @transformer.sql.should == "(IF(zoidberg < 10, nixon * 10, zoidberg / 5)) AS bar"
        end

        it "#transform should return the correct result" do
          @transformer.field_list = %w{id zoidberg nixon}
          @transformer.transform([1, 5, 10]).should == 100
          @transformer.transform([1, 15, 0]).should == 3
        end
      end
    end
  end
end
