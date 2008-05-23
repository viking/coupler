require File.dirname(__FILE__) + "/../../spec_helper.rb"

describe Linkage::Scores do
  def create_scores(options = {})
    Linkage::Scores.new({
      'combining method' => 'sum',
      'keys'     => (1..10).to_a,
      'num'      => 5,
      'range'    => 50..100,
      'defaults' => [0, 0, 0, 0, 0]
    }.merge(options))
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

  describe "#[]" do

    describe "when finalized" do
      before(:each) do
        @scores = create_scores
        5.times { |i| @scores.record { |r| } }
      end

      it "should return a score" do
        @scores[5, 8].should == 0
      end

      it "should return nil when the first argument is invalid" do
        @scores["foo", 1].should == nil
      end
    end

    it "should raise error if not finalized" do
      scores = create_scores
      lambda { scores[5, 8] }.should raise_error("not finalized yet!")
    end
  end

  describe "recording" do
    it "should accumulate scores with combining method is 'sum'" do
      scores = create_scores('num' => 3, 'defaults' => [0, 0, 0])
      scores.record { |r| r.add(1, 2, 10) }
      scores.record { |r| r.add(1, 2, 50) }
      scores.record { |r| r.add(1, 2, 30) }
      scores[1,2].should == 90
    end

    it "should average scores with combining method is 'mean'" do
      scores = create_scores('combining method' => 'mean')
      scores.record { |r| r.add(1, 2, 10) }
      scores.record { |r| r.add(1, 2, 50) }
      scores.record { |r| r.add(1, 2, 30) }
      scores.record { |r| r.add(1, 2, 80) }
      scores.record { |r| r.add(1, 2, 70) }
      scores[1,2].should == 48
    end

    it "should correctly add a score when the keys are reversed" do
      scores = create_scores('num' => 1)
      scores.record { |r| r.add(2, 1, 10) }
      scores[1,2].should == 10
    end

    it "should raise an exception if bad keys are used" do
      scores = create_scores
      lambda { scores.record { |r| r.add("foo", "bar", 10) } }.should raise_error("bad keys used for adding scores!")
    end

    describe "with different defaults" do
      before(:each) do
        @scores = create_scores('defaults' => [25, 20], 'num' => 2)
      end

      it "should accumulate scores correctly" do
        @scores.record { |r| r.add(1, 2, 30) }
        @scores.record { |r| r.add(2, 3, 50) }
        @scores[1, 2].should == 50
        @scores[2, 3].should == 75
      end
    end
  end

  describe "#each" do
    def do_record
      @scores.record do |r|
        (1..9).each do |i|
          ((i+1)..10).each do |j|
            r.add(i, j, i*10)
          end
        end
      end
      @scores.record do |r|
        (1..9).each do |i|
          ((i+1)..10).each do |j|
            r.add(i, j, i*6)
          end
        end
      end
    end

    it "should yield ids and sum of scores when combining method is 'sum'" do
      @scores = create_scores('num' => 2, 'range' => 0..1000)
      do_record

      expected = (1..9).inject([]) { |arr, i| ((i+1)..10).each { |j| arr << [i, j, i*16] }; arr }
      @scores.each do |id1, id2, score|
        [id1, id2, score].should == expected.shift
      end
      expected.should be_empty
    end

    it "should yield ids and mean of scores when combining method is 'mean'" do
      @scores = create_scores('num' => 2, 'combining method' => 'mean', 'range' => 0..100)
      do_record

      expected = (1..9).inject([]) { |arr, i| ((i+1)..10).each { |j| arr << [i, j, i*8] }; arr }
      @scores.each do |id1, id2, score|
        [id1, id2, score].should == expected.shift
      end
      expected.should be_empty
    end

    it "should not yield scores that are not in the specified range" do
      @scores = create_scores('num' => 2, 'combining method' => 'mean')
      do_record

      expected = (7..9).inject([]) { |arr, i| ((i+1)..10).each { |j| arr << [i, j, i*8] }; arr }
      @scores.each do |id1, id2, score|
        [id1, id2, score].should == expected.shift
      end
      expected.should be_empty
    end

    it "should raise an error if not finalized" do
      scores = create_scores
      lambda { scores.each { |a, b, c, d| } }.should raise_error("not finalized yet!")
    end
  end
end
