module Linkage
  class Resource
    class ResultSet
      def initialize(set, type)
        @set = set
        @type = type
        @closed = false
      end

      def each(&block)
        @set.each(&block)
      end

      def next
        case @type
        when 'mysql'
          @set.fetch
        when 'sqlite3'
          @set.next
        end
      end

      def close
        unless @closed
          @set.close
          @closed = true
        end
      end
    end

    @@resources = {}

    def self.find(name)
      @@resources[name]
    end

    attr_reader :name, :configuration, :table, :primary_key

    def initialize(options = {})
      @name = options['name']
      if @@resources.keys.include?(@name)
        raise "duplicate name"
      else
        @@resources[@name] = self
      end
      @configuration = options['connection']

      if options['table']
        @table = options['table']['name']
        @primary_key = options['table']['primary_key']
      end
    end

    def connection
      unless @connection
        case @configuration['adapter']
        when 'sqlite3'
          @connection = SQLite3::Database.new( @configuration['database'] )
          @connection.type_translation = true
        when 'mysql'
          @connection = Mysql.new(
            @configuration['host'],
            @configuration['username'],
            @configuration['password'],
            @configuration['database']
          )
        end
      end
      @connection
    end

    def select_all(*columns)
      select(:columns => columns)
    end

    def select_one(id, *columns)
      set = select(:columns => columns, :conditions => "WHERE ID = #{id.inspect}", :limit => 1)
      row = set.next
      set.close
      row
    end

    def select_num(num, *columns)
      options = columns.extract_options!
      select(:columns => columns, :limit => num, :offset => options[:offset])
    end

    def count
      set = select(:columns => ["COUNT(*)"])
      n = set.next[0]
      set.close
      n
    end

    def select(options = {})
      columns = options[:columns]
      columns.collect! { |c| c == "*" ? "#{@table}.*" : c }

      columns = columns.nil? || columns.empty? ? columns = "*" : columns.join(", ")
      conditions = options[:conditions] ? " #{options[:conditions]}" : ""
      limit      = options[:limit] ? " LIMIT #{options[:limit]}" : ""
      offset     = options[:offset] ? " OFFSET #{options[:offset]}" : ""
      
      qry = "SELECT #{columns} FROM #{@table}#{conditions}#{limit}#{offset}"
      Linkage.logger.debug("Resource (#{name}): #{qry}")  if Linkage.logger
      begin
        result = case @configuration['adapter']
                 when 'sqlite3' then connection.query(qry)
                 when 'mysql'   then connection.prepare(qry).execute
                 end
      rescue Exception => boom
        debugger
        p boom
      end
      ResultSet.new(result, @configuration['adapter'])
    end

    def insert(columns, values)
      connection.query("INSERT INTO #{@table} (#{columns.join(", ")}) VALUES(#{values.collect { |v| v.inspect }.join(", ")})")
    end

    def create_table(name, primary, *columns)
      key    = primary.split[0]
      fields = ([primary] + columns + ["PRIMARY KEY (#{key})"]).join(", ")
      connection.query("CREATE TABLE #{name} (#{fields})")
      @table = name
      @primary_key = primary.split(" ")[0]
    end

    def drop_table(name)
      begin
        connection.query("DROP TABLE #{name}")
        true
      rescue SQLite3::SQLException, Mysql::Error
        false
      end
    end
  end
end
