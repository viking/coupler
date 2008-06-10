module Linkage
  class Options
    def self.parse(args)
      options = Linkage::Options.new
      parser  = OptionParser.new do |opts|
        opts.on("-e", "--use-existing-scratch", "Don't recreate the scratch database") do |e|
          options.use_existing_scratch = true
        end
      end
      parser.parse!(args)
      options.filenames = args

      options
    end

    attr_accessor :filenames, :use_existing_scratch
    def initialize
      @use_existing_scratch = false
      @filenames = []
    end
  end
end
