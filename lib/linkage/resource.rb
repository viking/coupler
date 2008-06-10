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

    def self.reset
      @@resources.clear
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
      conditions = options[:conditions] ? " #{options[:conditions]}"     : ""
      limit      = options[:limit]      ? " LIMIT #{options[:limit]}"    : ""
      offset     = options[:offset]     ? " OFFSET #{options[:offset]}"  : ""
      order      = options[:order]      ? " ORDER BY #{options[:order]}" : ""
      
      qry = "SELECT #{columns} FROM #{@table}#{conditions}#{order}#{limit}#{offset}"
      result = run_and_log_query(qry)
      ResultSet.new(result, @configuration['adapter'])
    end

    def insert(columns, values)
      run_and_log_query("INSERT INTO #{@table} (#{columns.join(", ")}) VALUES(#{values.collect { |v| v ? v.inspect : 'NULL' }.join(", ")})")
    end

    def create_table(name, columns, indices = [])
      primary = columns.shift
      key     = primary.split[0]
      fields  = ([primary] + columns + ["PRIMARY KEY (#{key})"]).join(", ")
      run_and_log_query("CREATE TABLE #{name} (#{fields})")

      indices.each do |column|
        run_and_log_query("CREATE INDEX #{column}_index ON #{name} (#{column})")
      end

      @table = name
      @primary_key = primary.split(" ")[0]
    end

    def set_table_and_key(name, key)
      @table = name
      @primary_key = key
    end

    def drop_table(name)
      begin
        run_and_log_query("DROP TABLE #{name}")
        true
      rescue SQLite3::SQLException, Mysql::Error
        false
      end
    end

    def columns(names)
      case @configuration['adapter']
      when 'sqlite3'
        connection.table_info(@table).inject({}) do |hsh, info|
          hsh[info['name']] = info['type']  if names.include?(info['name'])
          hsh
        end
      when 'mysql'
        res = run_and_log_query("SHOW FIELDS FROM #{@table} WHERE Field IN (#{names.collect { |f| f.inspect }.join(", ")})")
        hsh = {}
        while (row = res.fetch)
          hsh[row[0]] = row[1]
        end
        hsh
      end
    end

    def keys
      res = run_and_log_query("SELECT #{@primary_key} FROM #{@table} ORDER BY #{@primary_key}")
      retval = []
      res.each { |row| retval << row[0] }
      retval
    end

    private
      def run_and_log_query(query)
        Linkage.logger.debug("Resource (#{name}): #{query}")  if Linkage.logger
        case @configuration['adapter']
        when 'sqlite3'
          connection.query(query)
        when 'mysql'
          connection.prepare(query).execute
        end
      end
  end
end
