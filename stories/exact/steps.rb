steps_for(:exact) do
  When("I run the $name specification") do |name|
    path = File.join(File.dirname(__FILE__), "files")
    Linkage::Runner.run(File.join(path, "#{name}.yml"))
  end

  Then("it should create the $filename file") do |filename|
    filename = filename
    File.exist?(filename).should be_true
    @results = FasterCSV.read(filename)
    @header  = @results.shift
  end

  Then("each record should match every $nth record with a score of $score") do |nth, expected_score|
    debugger
    n = nth.sub(/th$/, "").to_i
    expected_score = expected_score.to_i
    current = nil
    expected_ids = []
    to_delete = []
    @results.each_with_index do |row, i|
      id1 = row[0].to_i; id2 = row[1].to_i; score = row[2].to_i; group = row[3]

      if id1 != current
        if expected_ids.empty?
          upper        = (1000/n) - (id1-1)/n - 1
          expected_ids = (1..upper).collect { |i| id1 + i*n } 
          current      = id1
          puts "Expected ids for #{current}: #{expected_ids.inspect}"
        else
          raise "Record #{current} did not match as expected. (#{expected_ids.inspect})"
        end
      end

      if id2 == expected_ids[0]
        if score == expected_score
          to_delete << i
          expected_ids.shift
        else
          raise "#{id1} <=> #{id2} != #{expected_score} (was #{score})"
        end
      end
    end

    to_delete.each { |i| @results.delete_at(i) }
  end
end
