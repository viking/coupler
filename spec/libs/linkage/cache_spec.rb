require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Cache do
  before(:each) do
    @set = stub("result set", :close => nil, :next => nil)
    @scratch = stub("scratch resource", :primary_key => "ID", :select => @set)
    Linkage::Resource.stub!(:find).and_return(@scratch)
  end

  it "should find the scratch resource on create" do
    Linkage::Resource.should_receive(:find).and_return(@scratch)
    Linkage::Cache.new('scratch')
  end

  it "should accept a number of guaranteed records" do
    Linkage::Cache.new('scratch', 1000)
  end

  describe "when guaranteeing 10 records" do
    before(:each) do
      @cache = Linkage::Cache.new('scratch', 10)
      (1..11).each do |i|
        @cache.add(i, [i, "data #{i}"])
      end
    end

    it "should mark the first 10 records added" do
      GC.start
      @scratch.should_not_receive(:select).and_return(@set)
      @cache.fetch(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    end

    it "should have a window of marked records" do
      GC.start
      @scratch.should_receive(:select).and_return(@set)
      @cache.fetch(11)
    end
  end
  
  describe do
    before(:each) do
      @cache = Linkage::Cache.new('scratch')
    end

#    describe "#keys" do
#      it "should return keys" do
#        @cache.add(1, "data 1")
#        @cache.add(2, "data 2")
#        @cache.add(3, "data 3")
#        @cache.keys.sort.should == [1,2,3]
#      end
#    end
#
    describe "#add" do
      it "should add data to the cache" do
        @cache.add(1, "data 1")
      end
    end

    describe "#fetch" do
      before(:each) do
        (1..10).each do |i|
          @cache.add(i, [i, "data #{i}"])
        end
      end

      it "should fetch data that was just added" do
        @cache.fetch(1).should == [1, "data 1"]
      end

      it "should fetch more than one item" do
        @cache.fetch(1, 2, 3).should == [
          [1, "data 1"],
          [2, "data 2"],
          [3, "data 3"]
        ]
      end

      it "should accept an array of keys" do
        @cache.fetch([1,2,3]).should == [
          [1, "data 1"],
          [2, "data 2"],
          [3, "data 3"]
        ]
      end

      it "should always return a 2d array when passed an array" do
        @cache.fetch([1]).should == [[1, "data 1"]]
      end

      describe "when fetching GC'd object(s)" do
        before(:each) do
          GC.start
          @set.stub!(:next).and_return([1, "data 1"], nil)
          @scratch.stub!(:select).with({
            :conditions => "WHERE ID IN (1)",
            :columns => ["ID", "*"]
          }).and_return(@set)
        end

        it "should find the record in the database" do
          @scratch.should_receive(:select).with({
            :conditions => "WHERE ID IN (1)",
            :columns => ["ID", "*"]
          }).and_return(@set)
          @cache.fetch(1)
        end

        it "should re-cache the row when fetching a GC'd object" do
          @cache.fetch(1)
          @scratch.should_not_receive(:select)
          @cache.fetch(1)
        end

        it "should find multiple records in the database" do
          set = stub("result set", :close => nil)
          set.stub!(:next).and_return(["data 1"], ["data 2"], ["data 3"], nil)
          @scratch.should_receive(:select).with({
            :conditions => "WHERE ID IN (1, 2, 3)",
            :columns    => ["ID", "*"]
          }).and_return(set)

          @cache.fetch(1, 2, 3)
        end

        it "should close the result set" do
          @set.should_receive(:close)
          @cache.fetch(1)
        end
      end
    end
  end

end
