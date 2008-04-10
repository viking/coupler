require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Cache do
  before(:each) do
    @scratch = stub("scratch resource", :select_one => "some awesome data")
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
        @cache.add(1, "some awesome data")
        @cache.add(2, "some awesome data")
        @cache.add(3, "some awesome data")
        @cache.keys.sort.should == [1,2,3]
      end
    end

    describe "#add" do
      it "should add data to the cache" do
        @cache.add(1, "some awesome data")
      end
    end

    describe "#fetch" do
      before(:each) do
        @cache.add(1, "some awesome data")
      end

      it "should fetch data that was just added" do
        @cache.fetch(1).should == "some awesome data" 
      end

      describe "when fetching a GC'd object" do
        def fake_gc
          @cache.instance_eval do
            @cache.keys.each { |k| @cache[k] = :gone }
            @rev_cache.clear
          end
        end

        before(:each) do
          fake_gc
          @scratch.stub!(:select_one).with(1).and_return("some awesome data")
        end

        it "should find the record in the database" do
          @scratch.should_receive(:select_one).with(1).and_return("some awesome data")
          @cache.fetch(1)
        end

        it "should re-cache the row when fetching a GC'd object" do
          @cache.fetch(1)
          @scratch.should_not_receive(:select_one).with(1).and_return("some awesome data")
          @cache.fetch(1)
        end
      end
    end
  end
end
