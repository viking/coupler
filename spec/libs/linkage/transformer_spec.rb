require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Transformer do
  before(:each) do
    @opts = { 
      'name'    => 'optimus_prime',
      'formula' => 'x * 5',
      'default' => 'x',
    }
  end

  def create_xformer
    @xformer = Linkage::Transformer.new(@opts)
  end

  it "should have a name" do
    create_xformer
    @xformer.name.should == 'optimus_prime'
  end

  it "should have a formula" do
    create_xformer
    @xformer.formula.should == 'x * 5'
  end

  it "should have a default" do
    create_xformer
    @xformer.default.should == 'x'
  end

  it "should not raise an error without a default" do
    @opts['default'] = nil
    create_xformer
  end

  describe "with 1 parameter" do

    describe "with no options" do
      before(:each) do
        @opts['parameters'] = [ 'x' ]
        create_xformer
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
          @xformer.transform(5).should == 25
        end

        it "should add by 5" do
          @opts['formula'] = "x + 5"
          create_xformer
          @xformer.transform(5).should == 10
        end
      end
    end

    describe "with options" do
      before(:each) do
        @opts['parameters'] = [
          { 
            'name' => 'x',
            'coerce_to' => 'integer',
            'conditions' => { 'regexp' => '\d+' }
          }
        ]
        @opts['default'] = %{"foo"}
        create_xformer
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
          @xformer.transform("5").should == 25
        end

        it "should return the default value when parameter doesn't meet conditions" do
          @xformer.transform("blah").should == "foo"
        end
      end
    end
  end

  describe "with 3 parameters" do

    describe "with no options" do
      before(:each) do
        @opts['parameters'] = %w{x y z}
        @opts['formula']    = "x * y * z"
        create_xformer
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
          @xformer.transform(2, 3, 4).should == 24
        end
      end
    end

    describe "with options" do
      before(:each) do
        @opts['parameters'] = [
          { 'name' => 'x', 'coerce_to' => 'string' },
          { 'name' => 'y', 'coerce_to' => 'integer', 'conditions' => { 'regexp' => '^\d+$' } },
          { 'name' => 'z', 'coerce_to' => 'integer' }
        ]
        @opts['formula'] = "x * y * z"
        @opts['default'] = "y"
        create_xformer
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
          @xformer.transform(2, "3", 4).should == "2" * 12
        end

        it "should return the default value if any parameters don't meet conditions" do
          @xformer.transform(2, "bibbity boppity", 5).should == "bibbity boppity"
        end
      end
    end
  end

#  describe "#transform" do
#
#    describe "with 1 parameter" do
#
#      it "should have 1 parameter" do
#      end
#      it 'should multiply value by 5' do
#        create_xformer
#        @xformer.transform(5).should == 25
#      end
#
#      it "should convert value to integer before transforming" do
#        @opts['coerce_to'] = 'integer'
#        create_xformer
#        @xformer.transform("5").should == 25
#      end
#
#      it "should convert value to string before transforming" do
#        @opts['coerce_to'] = 'string'
#        create_xformer
#        @xformer.transform(5).should == "55555"
#      end
#
#      it "should not convert if value doesn't match regex" do
#        @opts['conditions'] = { 'regex' => '^\d+$' }
#        create_xformer
#        @xformer.transform("123foo").should == "123foo"
#      end
#    end
#
#    describe "with 3 parameters" do
#      before(:each) do
#        @opts['parameters'] = %w{x y z}
#        @opts['formula']    = "x * y * z"
#        @opts['name']       = "multiply_all"
#      end
#
#      it "should return the product of 3 values" do
#        create_xformer
#        @xformer.transform(2, 3, 4).should == 24
#      end
#    end
#  end
end

describe Linkage::Transformer::Parameter do
  it "should have a name" do
    p = Linkage::Transformer::Parameter.new('name' => 'x')
    p.name.should == 'x'
  end

  it "should have a coerce_to value" do
    p = Linkage::Transformer::Parameter.new('name' => 'x', 'coerce_to' => 'integer')
    p.coerce_to.should == 'integer'
  end

  it "should have a regexp" do
    p = Linkage::Transformer::Parameter.new({
      'name' => 'x',
      'coerce_to' => 'integer',
      'conditions' => { 'regexp' => '\d+' }
    })
    p.regexp.should == /\d+/
  end

  describe "#valid?" do
    it "should return true if there are no conditions" do
      p = Linkage::Transformer::Parameter.new('name' => 'x')
      p.valid?(123).should be_true
    end

    it "should return true if there is a regexp and value matches" do
      p = Linkage::Transformer::Parameter.new({
        'name' => 'x',
        'conditions' => { 'regexp' => '\d+' }
      })
      p.valid?(123).should be_true
    end
  end

  describe "#convert" do
    it "should return the value if no coercion needs to be done" do
      p = Linkage::Transformer::Parameter.new('name' => 'x')
      p.convert("blah").should == "blah"
    end

    it "should convert value to Fixnum if 'integer'" do
      p = Linkage::Transformer::Parameter.new('name' => 'x', 'coerce_to' => 'integer')
      p.convert("123").should == 123
    end

    it "should convert value to String if 'string'" do
      p = Linkage::Transformer::Parameter.new('name' => 'x', 'coerce_to' => 'string')
      p.convert(123).should == "123"
    end
  end
end
