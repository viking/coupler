require File.dirname(__FILE__) + "/../../../spec_helper.rb"

describe Coupler::Transformers::DefaultTransformer do

  @@num = 1
  def xformer_name
    @@num += 1
    "optimus_prime_#{@@num-1}"
  end

  def create_xformer(options = {})
    options = {
      'formula' => 'x * 5',
      'default' => 'x',
      'type'    => 'integer'
    }.merge(options)
    options['name'] = xformer_name  unless options['name']

    Coupler::Transformers::DefaultTransformer.new(options)
  end

  it "should have a name" do
    xf = create_xformer
    xf.name.should match(/optimus_prime_\d+/)
  end

  it "should have a formula" do
    xf = create_xformer
    xf.formula.should == 'x * 5'
  end

  it "should have a default" do
    xf = create_xformer
    xf.default.should == 'x'
  end

  it "should have a data type" do
    xf = create_xformer
    xf.data_type.should == 'integer'
  end

  it "should not raise an error without a default" do
    create_xformer('default' => nil)
  end

  it "should raise an error if a transformer has a duplicate name" do
    xf = create_xformer
    lambda { create_xformer('name' => xf.name) }.should raise_error
  end

  describe "with 1 parameter" do

    describe "with no options" do
      before(:each) do
        @xformer = create_xformer('parameters' => ['x'])
      end

      it "should have 1 parameter" do
        @xformer.should have(1).parameters
      end

      it "should have a parameter with a name of 'x'" do
        @xformer.parameters[0].name.should == 'x'
      end

      describe "when checking validity of parameters" do
        it "should return true" do
          @xformer.valid?("123").should be_true
        end
      end

      describe "when transforming" do
        it "should multiply integer by 5" do
          @xformer.transform('x' => 5).should == 25
        end

        it "should add by 5" do
          xf = create_xformer('formula' => 'x + 5', 'parameters' => ['x'])
          xf.transform('x' => 5).should == 10
        end
      end
    end

    describe "with options" do
      before(:each) do
        @xformer = create_xformer({
          'default' => %{"foo"},
          'parameters' => [
            { 
              'name' => 'x',
              'coerce_to' => 'integer',
              'regexp' => '\d+'
            }
          ]
        })
      end

      it "should have 1 parameter" do
        @xformer.should have(1).parameters
      end

      it "should have a parameter with a name of 'x'" do
        @xformer.parameters[0].name.should == 'x'
      end

      it "should have a coerce_to value of 'integer'" do
        @xformer.parameters[0].coerce_to.should == 'integer'
      end

      it "should have a regexp of /\d+/" do
        @xformer.parameters[0].regexp.should == /\d+/
      end

      describe "when checking validity of parameters" do
        it "should return true if regexp matches" do
          @xformer.valid?("123").should be_true
        end

        it "should return false if regexp doesn't match" do
          @xformer.valid?("foo").should be_false
        end
      end

      describe "when transforming" do
        it "should coerce string to integer before evaluating formula" do
          @xformer.transform('x' => "5").should == 25
        end

        it "should return the default value when parameter doesn't meet conditions" do
          @xformer.transform('x' => "blah").should == "foo"
        end
      end
    end
  end

  describe "with 3 parameters" do

    describe "with no options" do
      before(:each) do
        @xformer = create_xformer('parameters' => %w{x y z}, 'formula' => 'x * y * z')
      end

      it "should have 3 parameters" do
        @xformer.should have(3).parameters
      end

      describe "when checking validity of parameters" do
        it "should return true" do
          @xformer.valid?(1, 2, 3).should be_true
        end
      end

      describe "when transforming" do
        it "should multiply all parameters" do
          @xformer.transform('x' => 2, 'y' => 3, 'z' => 4).should == 24
        end
      end
    end

    describe "with options" do
      before(:each) do
        @xformer = create_xformer({
          'parameters' => [
            { 'name' => 'x', 'coerce_to' => 'string' },
            { 'name' => 'y', 'coerce_to' => 'integer', 'regexp' => '^\d+$' },
            { 'name' => 'z', 'coerce_to' => 'integer' }
          ],
          'formula' => 'x * y * z',
          'default' => 'y'
        })
      end

      it "should have 3 parameters" do
        @xformer.should have(3).parameters
      end

      describe "when checking validity of parameters" do
        it "should return true if all values match corresponding regexp's" do
          @xformer.valid?(1, 2, 3).should be_true
        end

        it "should be false if one value doesn't match its regexp" do
          @xformer.valid?(1, "foo", 3).should be_false
        end
      end

      describe "when transforming" do
        it "should return the evaluated formula if all parameters meet conditions" do
          @xformer.transform('x' => 2, 'y' => "3", 'z' => 4).should == "2" * 12
        end

        it "should return the default value if any parameters don't meet conditions" do
          @xformer.transform('x' => 2, 'y' => "bibbity boppity", 'z' => 5).should == "bibbity boppity"
        end
      end
    end
  end

  describe "#transform" do
    it "should require a Hash as an argument" do
      xf = create_xformer('parameters' => ['x'])
      lambda { xf.transform("foo") }.should raise_error
    end
  end
end
