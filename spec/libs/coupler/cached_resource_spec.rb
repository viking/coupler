require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Coupler::CachedResource do

  before(:each) do
    @set = stub("result set", :close => nil, :next => nil)
    @scratch = stub("scratch resource", :primary_key => "ID")
    @scratch.stub!(:select).and_return { @set.should_receive(:close).any_number_of_times; @set }
    @options = Coupler::Options.new
    Coupler::Resource.stub!(:find).and_return(@scratch)
  end

  it "should find the scratch resource on create" do
    Coupler::Resource.should_receive(:find).and_return(@scratch)
    Coupler::CachedResource.new('scratch', @options)
  end

  describe "when --db-limit is 50000" do
    before(:each) do
      @options.db_limit = 50000
      @cache = Coupler::CachedResource.new('scratch', @options)
    end

    it "#auto_fill! should select all records from the database, 50000 at a time" do
      first_set = stub("first result set", :close => nil)
      first_set.stub!(:next).and_return([1, 1, "data 1"], nil)
      second_set = stub("second result set", :close => nil)
      second_set.stub!(:next).and_return([2, 2, "data 2"], nil)

      @scratch.stub!(:count).and_return(100000)
      @scratch.should_receive(:select).with({
        :columns => ["ID", "*"],
        :limit => 50000,
        :offset => 0
      }).and_return(first_set)
      @scratch.should_receive(:select).with({
        :columns => ["ID", "*"],
        :limit => 50000,
        :offset => 50000
      }).and_return(second_set)
      first_set.should_receive(:close)
      second_set.should_receive(:close)
      @cache.auto_fill!
    end
  end

  describe "when guaranteeing 10 records" do
    before(:each) do
      @options.guaranteed = 10
      @cache = Coupler::CachedResource.new('scratch', @options)
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
      @set.should_receive(:close).any_number_of_times
      @cache.fetch(11)
    end
  end
  
  describe do
    before(:each) do
      @cache = Coupler::CachedResource.new('scratch', @options)
    end

    describe "#count" do
      it "should return number of items" do
        (1..10).each { |i| @cache.add(i, [i, "data #{i}"]) }
        @cache.count.should == 10
      end
    end

    describe "#keys" do
      it "should return keys in order of creation" do
        (1..100).each { |i| @cache.add(i, [i, "data #{i}"]) }
        @cache.keys.should == (1..100).to_a
      end
    end

    describe "#add" do
      it "should add data to the cache" do
        @cache.add(1, "data 1")
      end
    end

    describe "#clear" do
      before(:each) do
        (1..10).each do |i|
          @cache.add(i, [i, "data #{i}"])
        end
        @cache.clear
      end

      it "should clear keys" do
        @cache.keys.should be_empty
      end

      it "should clear the cache" do
        @cache.fetch(1).should be_nil
      end

      it "should set count to 0" do
        @cache.count.should == 0
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
          }).and_return { @set.should_receive(:close); @set }
        end

        it "should only select fields we need!"

        it "should find the record in the database" do
          @scratch.should_receive(:select).with({
            :conditions => "WHERE ID IN (1)",
            :columns => ["ID", "*"]
          }).and_return(@set)
          @set.should_receive(:close)
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
          set.should_receive(:close).any_number_of_times
          @scratch.should_receive(:select).with({
            :conditions => "WHERE ID IN (1, 2, 3)",
            :columns    => ["ID", "*"]
          }).and_return(set)

          @cache.fetch(1, 2, 3)
        end
      end
    end   # end fetch

    describe "#auto_fill!" do
      before(:each) do
        @first_set = stub("first result set", :close => nil)
        @first_set.stub!(:next).and_return([1, 1, "data 1"], nil)
        @second_set = stub("second result set", :close => nil)
        @second_set.stub!(:next).and_return([2, 2, "data 2"], nil)

        @scratch.stub!(:select).with({
          :columns => ["ID", "*"],
          :limit => 10000,
          :offset => 0
        }).and_return { @first_set.should_receive(:close); @first_set }
        @scratch.stub!(:select).with({
          :columns => ["ID", "*"],
          :limit => 10000,
          :offset => 10000
        }).and_return { @second_set.should_receive(:close); @second_set }
        @scratch.stub!(:count).and_return(20000)
      end

      it "should select all records from the database, 10000 at a time" do
        @scratch.should_receive(:select).with({
          :columns => ["ID", "*"],
          :limit => 10000,
          :offset => 0
        }).and_return(@first_set)
        @scratch.should_receive(:select).with({
          :columns => ["ID", "*"],
          :limit => 10000,
          :offset => 10000
        }).and_return(@second_set)
        @first_set.should_receive(:close)
        @second_set.should_receive(:close)
        @cache.auto_fill!
      end

      it "should add all records" do
        @cache.auto_fill!
        @cache.fetch(1, 2).should == [[1, "data 1"], [2, "data 2"]]
      end

      it "should set keys correctly" do
        @cache.auto_fill!
        @cache.keys.should == [1, 2]
      end
    end
  end
end
