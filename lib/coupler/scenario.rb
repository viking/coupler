module Coupler
  class Scenario
    DEBUG = ENV['DEBUG']

    attr_reader :name, :type, :resources, :field_list, :indices, :range,
                :combining_method, :scratches
    def initialize(spec, options)
      @options   = options
      @name      = spec['name']
      @type      = spec['type']
      @range     = (r = spec['scoring']['range']).is_a?(Range) ? r : eval(r)
      @combining_method = spec['scoring']['combining method']
      @indices   = []
      @resources = []
      @scratches = []

      rnames = []
      case @type
      when 'self-join'
        rnames << spec['resource']
      when 'dual-join'
        rnames |= spec['resources']
      else
        raise "unsupported scenario type"
      end
      rnames.each do |rname|
        @resources << Coupler::Resource.find(rname)
        @scratches << Coupler::Resource.find("#{rname}_scratch")
        raise "can't find resource '#{rname}'"  if @resources[-1].nil?
      end

      # grab fields
      # NOTE: matcher fields can either be real database columns or the resulting field of
      #       a transformation (which can be named the same thing as the real database
      #       column).
      @field_list = spec['matchers'].inject([]) do |list, m|
        list | (m['field'] ? [m['field']] : m['fields'])
      end

      @master_matcher = Coupler::Matcher::Master.new(self, @options)
      spec['matchers'].each do |m|
        case m['type']
        when 'exact'
          # << takes precedence over || because of the original semantics of <<
          @indices << (m['field'] || m['fields'])
        end
        @master_matcher.add_matcher(m)
      end

      # other
      @conditions = spec['conditions']
      @limit = spec['limit']  # undocumented and untested, wee!
    end

    def run
      return  if @options.dry_run
      Coupler.logger.info("Scenario (#{name}): Run start")  if Coupler.logger

      # now match!
      Coupler.logger.info("Scenario (#{name}): Matching records")  if Coupler.logger
      retval = @master_matcher.score

      if @options.csv_output
        FasterCSV.open("#{@name}.csv", "w") do |csv|
          csv << %w{id1 id2 score}
          retval.each do |id1, id2, score|
            csv << [id1, id2, score]
          end
        end
      end
    end
  end
end
