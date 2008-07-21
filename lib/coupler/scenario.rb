module Coupler
  class Scenario
    DEBUG = ENV['DEBUG']

    attr_reader :name, :type, :resource, :resources, :field_list, :indices
    def initialize(spec, options)
      @options   = options
      @name      = spec['name']
      @type      = spec['type']
      @guarantee = spec['guarantee']  # TODO: move this to command-line
      @range     = (r = spec['scoring']['range']).is_a?(Range) ? r : eval(r)
      @indices   = []
      @resources = []

      case @type
      when 'self-join'
        @resource = Coupler::Resource.find(spec['resource'])
        @resources << @resource
        raise "can't find resource '#{spec['resource']}'"   unless @resource
        @primary_key = @resource.primary_key
      else
        raise "unsupported scenario type"
      end
      @scratch = Coupler::Resource.find('scratch')
      @scores  = Coupler::Resource.find('scores')
      @cache   = if @guarantee then Coupler::Cache.new('scratch', options, @guarantee)
                 else Coupler::Cache.new('scratch', options) end

      # grab fields
      # NOTE: matcher fields can either be real database columns or the resulting field of
      #       a transformation (which can be named the same thing as the real database
      #       column).
      @field_list = spec['matchers'].inject([@primary_key]) do |list, m|
        list | (m['field'] ? [m['field']] : m['fields'])
      end

      @master_matcher = Coupler::Matchers::MasterMatcher.new({
        'field list'       => @field_list,
        'combining method' => spec['scoring']['combining method'],
        'range'            => @range,
        'cache'            => @cache,
        'resource'         => @scratch,
        'scores'           => @scores,
        'name'             => @name 
      }, @options)

      @use_cache = false
      spec['matchers'].each do |m|
        case m['type']
        when 'exact'
          # << takes precedence over || because of the original semantics of <<
          @indices << (m['field'] || m['fields'])
        else
          @use_cache = true
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

      # setup scratch database
      @scratch.set_table_and_key(@resource.name, @resource.primary_key)
      @cache.clear
      @cache.auto_fill!   if @use_cache

      # now match!
      Coupler.logger.info("Scenario (#{name}): Matching records")  if Coupler.logger
      retval = @master_matcher.score

      if DEBUG
        puts "*** Cache summary ***"
        puts "Fetches: #{@cache.fetches}"
        puts "Misses:  #{@cache.misses}"
      end

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
