steps_for(:family) do
  When("I run the $name specification") do |name|
    path = File.join(File.dirname(__FILE__), "files")
    Linkage::Runner.run(File.join(path, "#{name}.yml"))
  end

  Then("it should create the $filename file") do |filename|
    @filename = filename
    File.exist?(filename).should be_true
  end

  Then("that file should have scores") do
  end
end
