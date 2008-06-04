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
    @results = Hash.new { |h, k| h[k] = {} }
    @matched = Hash.new { |h, k| h[k] = [] }
    FasterCSV.foreach(filename) do |row|
      next  if row[0] == "id1"
      id1 = row[0].to_i; id2 = row[1].to_i; score = row[2].to_i
      @results[id1][id2] = score
    end
    File.delete(filename)
  end

  Then "every $nth record should match nothing" do |nth|
    n = nth.sub(/th$/, "").to_i

    (1000/n+1).times do |i|
      id1 = i * n + 1
      @matched[id1] = (1..1000).to_a
      if !@results[id1].empty?
        raise "#{id1} wasn't supposed to match anything, but matched #{@results[id1].inspect}"
      end

      (1..(id1-1)).each do |id2|
        @results[id2][id1].should be_nil
        @matched[id2] << id1
      end
    end
  end

  Then "each record should match every $nth record with a score of $score" do |nth, expected_score|
    n = nth.sub(/th$/, "").to_i
    expected_score = expected_score.to_i

    (1..1000).each do |id1|
      expected_ids   = ((id1+1)..1000).select { |id2| (id2-id1) % n == 0 } - @matched[id1]
      @matched[id1] += expected_ids

      expected_ids.each do |id2|
        score = @results[id1][id2]
        if score != expected_score
          raise "#{id1} <=> #{id2} should be #{expected_score}, but was #{score.inspect}"
        end
        @results[id1].delete(id2)
      end
    end
  end

  Then "there should be no extra scores" do
    @results.keys.inject(0) { |sum, key| sum + @results[key].length }.should == 0
  end
end
