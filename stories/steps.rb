steps_for(:coupler) do
  FIXDIR = File.expand_path(File.dirname(__FILE__) + "/fixtures")

  Given "the $name specification" do |name|
    logger = Logger.new("log/story.log")
    logger.level = Logger::DEBUG
    Coupler.logger = logger

    Coupler::Resource.reset
    Coupler::Transformer.reset

    @options  = Coupler::Options.new
    @spec_raw = File.read(File.join(FIXDIR, "#{name}.yml.erb"))
  end

  Given "that I want to use the $adapter adapter" do |adapter|
    @spec = YAML.load(Erubis::Eruby.new(@spec_raw).result(binding))
  end

  When "I transform the resources" do
    Coupler::Runner.transform(@spec, @options)
  end
end
