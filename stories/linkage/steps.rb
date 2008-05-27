steps_for(:linkage) do
  Given "the $name specification" do |name|
    @yamlfn = File.join(File.dirname(__FILE__), "files", "#{name}.yml")
    Linkage::Resource.reset
    Linkage::Transformer.reset
  end

  When "I run the scenarios" do
    Linkage::Runner.run(@yamlfn)
  end

  Then "it should create the $filename file" do |filename|
    filename = filename
    File.exist?(filename).should be_true
    @results = Hash.new { |h, k| h[k] = [] }
    @matched = Hash.new { |h, k| h[k] = [] }
    FasterCSV.foreach(filename) do |row|
      next  if row[0] == "id1"
      row[0] = row[0].to_i; row[1] = row[1].to_i; row[2] = row[2].to_i
      @results[row[0]] << row 
    end
  end

  Then "each record should match every $nth record with a score of $score" do |nth, expected_score|
    filename = filename
    n = nth.sub(/th$/, "").to_i
    expected_score = expected_score.to_i

    @results.each_pair do |id, scores|
      upper        = (1000/n) - (id-1)/n - 1
      expected_ids = (1..upper).collect { |i| id + i*n } - @matched[id] 
      @matched[id] += expected_ids
      (scores.length-1).downto(0) do |i|
        id1, id2, score, group = scores[i]
        if id2 == expected_ids.last
          if score == expected_score
            expected_ids.pop
            scores.delete_at(i)
          else
            raise "#{id1} <=> #{id2} != #{expected_score} (was #{score})"
          end
        end
      end

      if !expected_ids.empty?
        raise "#{id} didn't match these ids: #{expected_ids.join(", ")}"
      end
    end
  end

  Then "there should be no extra scores" do
    @results.keys.inject(0) { |sum, key| sum + @results[key].length }.should == 0
  end
end
