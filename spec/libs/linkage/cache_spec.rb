require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Cache do
  before(:each) do
    @scratch = stub("scratch resource", :primary_key => "ID")
    @weakref = "some awesome data"
    @weakref.stub!(:weakref_alive?).and_return(true)
    WeakRef.stub!(:new).and_return(@weakref)
    Linkage::Resource.stub!(:find).and_return(@scratch)
  end

  it "should find the scratch resource on create" do
    Linkage::Resource.should_receive(:find).and_return(@scratch)
    Linkage::Cache.new('scratch')
  end

  describe do
    before(:each) do
      @cache = Linkage::Cache.new('scratch')
    end

    describe "#keys" do
      it "should return keys" do
        @cache.add(1, "data 1")
        @cache.add(2, "data 2")
        @cache.add(3, "data 3")
        @cache.keys.sort.should == [1,2,3]
      end
    end

    describe "#add" do
      it "should add data to the cache" do
        @cache.add(1, "data 1")
      end
    end

    describe "#fetch" do
      before(:each) do
        (1..10).each do |i|
          @cache.add(i, "data #{i}")
        end
      end

      it "should fetch data that was just added" do
        @cache.fetch(1).should == "data 1" 
      end

      it "should fetch more than one item" do
        @cache.fetch(1, 2, 3).should == {
          1 => "data 1",
          2 => "data 2",
          3 => "data 3"
        }
      end

      it "should accept an array of keys" do
        @cache.fetch([1,2,3]).should == {
          1 => "data 1",
          2 => "data 2",
          3 => "data 3"
        }
      end

      describe "when fetching GC'd object(s)" do
        def fake_gc
          @cache.instance_eval do
            @cache.keys.each { |k| @cache[k] = :gone }
            @rev_cache.clear
          end
        end

        before(:each) do
          fake_gc
          @set = stub("result set")
          @set.stub!(:next).and_return([1, "some awesome data"], nil)
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
          set = stub("result set")
          set.stub!(:next).and_return(["data 1"], ["data 2"], ["data 3"], nil)
          @scratch.should_receive(:select).with({
            :conditions => "WHERE ID IN (1, 2, 3)",
            :columns    => ["ID", "*"]
          }).and_return(set)

          @cache.fetch(1, 2, 3)
        end
      end
    end
  end
end
