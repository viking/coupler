require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Scores do
  def create_scores(spec = {}, opts = {})
    Linkage::Scores.new({
      'combining method' => 'sum',
      'keys'     => (1..10).to_a,
      'num'      => 5,
      'range'    => 50..100,
      'defaults' => [0, 0, 0, 0, 0],
      'resource' => @resource,
      'name'     => 'foo'
    }.merge(spec), @options)
  end

  def an_array
    an_instance_of(Array)
  end

  before(:each) do
    @options = Linkage::Options.new
    @options.csv_output = true
    @query_result = stub('query result set', :close => nil, :next => nil)
    @resource = stub(Linkage::Resource, {
      :update_all => nil, :insert => nil, :replace => nil,
      :update => nil, :primary_key => "sid", :select => @query_result,
      :drop_table => nil, :create_table => nil, :replace_scores => nil,
      :drop_column => nil
    })
  end

  it "should drop any existing scores table" do
    @resource.should_receive(:drop_table).with('foo')
    create_scores
  end

  it "should create the scores table" do
    @resource.should_receive(:create_table).with(
      'foo', ["sid bigint", "id1 int", "id2 int", "score int", "flags int"]
    )
    create_scores
  end

  describe "::Recorder" do
    before(:each) do
      @scores   = create_scores
      @recorder = Linkage::Scores::Recorder.new(@scores)
    end

    it "should have a parent" do
      @recorder.parent.should == @scores
    end

    describe "#add" do
      it "should call add on the parent" do
        @scores.should_receive(:add).with(1, 2, 50)
        @recorder.add(1, 2, 50)
      end
    end
  end

  describe "#record" do
    before(:each) do
      @scores = create_scores
    end

    it "should yield a recorder" do
      @scores.record do |r|
        r.should be_an_instance_of(Linkage::Scores::Recorder)
      end
    end

    it "should raise an error if called too many times" do
      @scores.record { |r| }
      @scores.record { |r| }
      @scores.record { |r| }
      @scores.record { |r| }
      @scores.record { |r| }
      lambda { @scores.record { |r| } }.should raise_error("already finalized")
    end
  end

  describe "recording" do

    it "should raise an exception if bad keys are used" do
      scores = create_scores
      lambda { scores.record { |r| r.add("foo", "bar", 10) } }.should raise_error("bad keys used for adding scores!")
    end

    it "should always insert scores on the first pass" do
      scores = create_scores
      @resource.should_receive(:insert) do |columns, *values|
        columns.should == %w{sid id1 id2 score flags}
        values.sort { |a, b| a[0] <=> b[0] }.should == [
          [1, 1, 2, 20, 2], [2, 1, 3, 30, 2], [3, 1, 4, 40, 2], [4, 1, 5, 50, 2], 
          [5, 1, 6, 60, 2], [6, 1, 7, 70, 2], [7, 1, 8, 80, 2], [8, 1, 9, 90, 2],
          [9, 1, 10, 100, 2]  
        ]
      end
      scores.record do |r|
        (2..10).each { |i| r.add(1, i, i*10) }
      end
    end

    describe "after the first pass" do
      before(:each) do
        @scores = create_scores
        @scores.record { |r| }
        
        @query_result = stub('query result set', :close => nil)
        @query_result.stub!(:next).and_return(
          [1, 20, 2], [3, 40, 2], [5, 60, 2], [7, 80, 2],
          [9, 100, 2], nil
        )
        @resource.stub!(:select).and_return(@query_result)
      end

      it "should select score and flags from the resource" do
        ids = (1..9).collect { |i| i.to_s }
        @resource.should_receive(:select) do |selector, options|
          selector.should == :all
          options[:columns].should == %w{sid score flags}
          options[:order].should == "sid"
          options[:conditions].gsub(/\d+/) { |id| ids.delete(id).should == id }
          @query_result
        end
        @scores.record do |r|
          (2..10).each { |i| r.add(1, i, i*10) }
        end
      end

      it "should close the query result" do
        @query_result.should_receive(:close)
        @scores.record do |r|
          (2..10).each { |i| r.add(1, i, i*10) }
        end
      end

      it "should replace all scores with correct values" do
        @resource.should_receive(:replace) do |columns, *values|
          columns.should == %w{sid id1 id2 score flags}
          values.sort { |a, b| a[0] <=> b[0] }.should == [
            [1, 1, 2, 40, 6], [2, 1, 3, 30, 4], [3, 1, 4, 80, 6], [4, 1, 5, 50, 4], 
            [5, 1, 6, 120, 6], [6, 1, 7, 70, 4], [7, 1, 8, 160, 6], [8, 1, 9, 90, 4],
            [9, 1, 10, 200, 6]  
          ]
        end
        @scores.record do |r|
          (2..10).each { |i| r.add(1, i, i*10) }
        end
      end
    end

    describe "when not using CSV's after the final pass" do
      before(:each) do
        @options.csv_output = false
        @scores = create_scores('num' => 2, 'defaults' => [13, 37])
        @scores.record { |r| }

        @query_result = stub('query result set', :close => nil)
        @query_result.stub!(:next).and_return(
          [1, 20, 2], [3, 40, 4], [5, 60, 2], [7, 80, 4],
          [9, 100, 2], nil
        )
        @nil_result = stub('nil result set', :next => nil, :close => nil)
        @resource.stub!(:select).with(:all, {
          :conditions => "WHERE flags != 6",
          :columns    => %w{sid score flags},
          :limit      => 10000
        }).and_return(@query_result)

        @resource.stub!(:select).with(:all, {
          :conditions => "WHERE flags != 6",
          :columns    => %w{sid score flags},
          :limit      => 10000,
          :offset     => 10000
        }).and_return(@nil_result)
      end

      it "should find all scores that aren't finished" do
        @resource.should_receive(:select).with(:all, {
          :conditions => "WHERE flags != 6",
          :columns    => %w{sid score flags},
          :limit      => 10000
        }).and_return(@query_result)
        @scores.record { |r| }
      end

      it "should close result sets" do
        @query_result.should_receive(:close)
        @nil_result.should_receive(:close)
        @scores.record { |r| }
      end

      it "should replace the scores appropriately" do
        @resource.should_receive(:replace).with(
          %w{sid score}, [1, 57], [3, 53], [5, 97],
          [7, 93], [9, 137]
        )
        @scores.record { |r| }
      end

      it "should update all scores by dividing by the total if using means" do
        scores = create_scores('num' => 2, 'defaults' => [13, 37], 'combining method' => 'mean')
        scores.record { |r| }
        @resource.should_receive(:update_all).with("score = score / 2")
        scores.record { |r| }
      end

      it "should drop the flags column" do
        @resource.should_receive(:drop_column).with('flags')
        @scores.record { |r| }
      end

      it "should select up to 50000 records when --db-limit is 50000" do
        @options.db_limit = 50000
        scores = create_scores('num' => 2, 'defaults' => [13, 37])
        scores.record { |r| }

        @resource.should_receive(:select).with(
          :all, hash_including(:limit => 50000, :offset => 50000)
        ).and_return(@nil_result)
        @resource.should_receive(:select).with(
          :all, hash_including(:limit => 50000)
        ).and_return(@query_result)

        scores.record { |r| }
      end
    end

    it "should buffer scores up to 10000" do
      scores = create_scores
      buff   = scores.instance_variable_get("@score_buffer")
      buff.stub!(:length).and_return(10000)  # hackery
      @resource.should_receive(:insert).with(%w{sid id1 id2 score flags}, [1, 1, 2, 20, 2])
      @resource.should_receive(:insert).with(%w{sid id1 id2 score flags}, [2, 1, 3, 30, 2])
      scores.record do |r|
        r.add(1, 2, 20)
        r.add(1, 3, 30)
      end
    end

    it "should choose a score id based on the ids involved" do
      scores = create_scores
      @resource.should_receive(:insert).with(%w{sid id1 id2 score flags}, [35, 5, 10, 30, 2])
      scores.record { |r| r.add(5, 10, 30) }
    end

    it "should correctly insert scores into the database when the keys are reversed" do
      scores = create_scores
      @resource.should_receive(:insert).with(%w{sid id1 id2 score flags}, [1, 1, 2, 30, 2])
      scores.record { |r| r.add(2, 1, 30) }
    end

    it "should add the correct flag depending on the pass" do
      scores = create_scores('num' => 5)

      @resource.should_receive(:insert).with(%w{sid id1 id2 score flags}, [1, 1, 2, 30, 2])
      scores.record { |r| r.add(1, 2, 30) }

      @resource.should_receive(:replace).with(%w{sid id1 id2 score flags}, [2, 1, 3, 30, 4])
      scores.record { |r| r.add(1, 3, 30) }

      @resource.should_receive(:replace).with(%w{sid id1 id2 score flags}, [3, 1, 4, 30, 8])
      scores.record { |r| r.add(1, 4, 30) }

      @resource.should_receive(:replace).with(%w{sid id1 id2 score flags}, [4, 1, 5, 30, 16])
      scores.record { |r| r.add(1, 5, 30) }

      @resource.should_receive(:replace).with(%w{sid id1 id2 score flags}, [5, 1, 6, 30, 32])
      scores.record { |r| r.add(1, 6, 30) }
    end
  end

  describe "#each" do
    def do_record
      @num.times do |i|
        @scores.record { |r| }
      end
    end

    before(:each) do
      @scores_set = stub("scores result set", :close => nil)
      @scores_set.stub!(:next).and_return( [1, 2, 50, 6], [2, 3, 50, 6], nil )
      @resource.stub!(:select).and_return(@scores_set)
    end

    it "should select all scores" do
      @scores = create_scores('num' => (@num = 2))
      do_record
      @resource.should_receive(:select).with(:all, {
        :columns => %w{id1 id2 score flags},
        :order => "sid"
      }).and_return(@scores_set)
      @scores.each { |id1, id2, score| }
    end

    it "should yield ids and sum of scores when combining method is 'sum'" do
      @scores = create_scores('num' => (@num = 2), 'range' => 0..1000)
      do_record

      expected = [[1, 2, 50], [2, 3, 50]]
      @scores.each do |id1, id2, score|
        [id1, id2, score].should == expected.shift
      end
      expected.should be_empty
    end

    it "should fill in defaults for scores that aren't final" do
      @scores_set.stub!(:next).and_return( [1, 2, 40, 2], [2, 3, 25, 4], [3, 4, 50, 6], nil )
      @scores = create_scores('num' => (@num = 2), 'defaults' => [30, 50], 'range' => 0..1000)
      do_record

      expected = [[1, 2, 90], [2, 3, 55], [3, 4, 50]]
      @scores.each do |id1, id2, score|
        [id1, id2, score].should == expected.shift
      end
      expected.should be_empty
    end

    it "should yield ids and mean of scores when combining method is 'mean'" do
      @scores = create_scores('num' => (@num = 2), 'combining method' => 'mean', 'range' => 0..100)
      do_record

      expected = [[1, 2, 25], [2, 3, 25]]
      @scores.each do |id1, id2, score|
        [id1, id2, score].should == expected.shift
      end
      expected.should be_empty
    end

    it "should not yield scores that are not in the specified range" do
      @scores = create_scores('num' => (@num = 2), 'range' => 50..100)
      do_record

      @scores_set.stub!(:next).and_return( [1, 2, 75, 6], [2, 3, 25, 6], nil )
      @scores.each do |id1, id2, score|
        [id1, id2, score].should == [1, 2, 75]
      end
    end

    it "should close the result set!" do
      @scores = create_scores('num' => (@num = 2), 'range' => 50..100)
      do_record
      @scores_set.should_receive(:close)
      @scores.each { |id1, id2, score| }
    end

    it "should raise an error if not finalized" do
      scores = create_scores
      lambda { scores.each { |a, b, c, d| } }.should raise_error("not finalized yet!")
    end
  end
end
