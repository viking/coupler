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
        opts.on("-l", "--db-limit NUMBER", "Limit to use for database queries (default 10000)") do |number|
          options.db_limit = number.to_i
        end
        opts.on("-d", "--dry-run", "Don't actually do anything") do
          options.dry_run = true
        end
      end
      parser.parse!(args)
      options.filenames = args

      options
    end

    attr_accessor :filenames, :use_existing_scratch, :csv_output, :db_limit, :dry_run
    def initialize
      @use_existing_scratch = false
      @csv_output = false
      @filenames = []
      @db_limit = 10000
      @dry_run = false
    end
  end
end
