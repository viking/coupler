steps_for(:runner) do

  Given "that I want CSV output files" do
    @options.csv_output = true
  end

  When "I run the scenarios" do
    Coupler::Resource.reset
    Coupler::Transformer.reset
    Coupler::Runner.run(@spec, @options)
    @resource = Coupler::Resource.find('people')
    @total    = @resource.count.to_i
    @results  = Hash.new { |h, k| h[k] = {} }
    @matched  = Hash.new { |h, k| h[k] = [] }
  end

  Then "it should create $filename" do |filename|
    File.exist?(filename).should be_true
    @sname = filename.sub(/\.csv$/, "")

    FasterCSV.foreach(filename) do |row|
      next  if row[0] == "id1"
      id1 = row[0].to_i; id2 = row[1].to_i; score = row[2].to_i
      @results[id1][id2] = score
    end
    File.delete(filename)
  end

#  Then "it should store scores in the $table table" do |table|
#    @results.clear
#    @matched.clear
#
#    resource = Coupler::Resource.find('scores')
#    resource.set_table_and_key(table, "sid")
#    res = resource.select(:all, :columns => %w{sid id1 id2 score}, :order => "sid")
#    while (record = res.next)
#      @results[record[1].to_i][record[2].to_i] = record[3].to_i
#    end
#    res.close
#  end

  Then "every $nth record should match nothing" do |nth|
    n = nth.sub(/th$/, "").to_i

    (@total/n+1).times do |i|
      id1 = i * n + 1
      @matched[id1] = (1..@total).to_a
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

    (1..@total).each do |id1|
      expected_ids   = ((id1+1)..@total).select { |id2| (id2-id1) % n == 0 } - @matched[id1]
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
