module Coupler
  class Options
    def self.parse(args)
      options = Coupler::Options.new
      parser  = OptionParser.new do |opts|
        script_name = File.basename($0)
        opts.banner = "Usage: #{script_name} [options] <filename>"
        opts.on("-c", "--csv", "Create CSV output file(s)") do
          options.csv_output = true
        end
        opts.on("-l", "--db-limit NUMBER", "Limit to use for database queries (default 10000)") do |number|
          options.db_limit = number.to_i
        end
        opts.on("-g", "--guaranteed NUMBER", "Number to always keep in caches") do |number|
          options.guaranteed = number.to_i
        end
        opts.on("-v", "--verbose", "Be verbose in logs") do
          options.log_level = Logger::DEBUG
        end
        opts.on("-f", "--log-file FILENAME", "Specify custom log file") do |filename|
          options.log_file = filename
        end
        opts.on("-d", "--dry-run", "Don't actually do anything") do
          options.dry_run = true
        end
      end
      parser.parse!(args)
      options.filename = args.first

      options
    end

    attr_accessor :filename, 
                  :csv_output,
                  :db_limit,
                  :dry_run,
                  :log_level,
                  :log_file,
                  :guaranteed,
                  :specification

    def initialize
      @csv_output = false
      @filename   = nil
      @db_limit   = 10000
      @dry_run    = false
      @log_level  = Logger::INFO
      @log_file   = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "log", "runner.log"))
      @guaranteed = 0
    end
  end
end
