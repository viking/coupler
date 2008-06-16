module Linkage
  class Options
    def self.parse(args)
      options = Linkage::Options.new
      parser  = OptionParser.new do |opts|
        opts.on("-e", "--use-existing-scratch", "Don't recreate the scratch database") do
          options.use_existing_scratch = true
        end
        opts.on("-c", "--csv", "Create CSV output file(s)") do
          options.csv_output = true
        end
      end
      parser.parse!(args)
      options.filenames = args

      options
    end

    attr_accessor :filenames, :use_existing_scratch, :csv_output
    def initialize
      @use_existing_scratch = false
      @csv_output = false
      @filenames = []
    end
  end
end
