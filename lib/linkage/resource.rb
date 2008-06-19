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
      @adapter = @configuration['adapter']

      if options['table']
        @table = options['table']['name']
        @primary_key = options['table']['primary_key']
      end
    end

    def connection
      unless @connection
        case @adapter
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

    def close
      @connection.close   if connection
      @connection = nil
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

    def select(*args)
      # FIXME: put WHERE automatically into conditions, dummy.
      options = args.extract_options!
      columns = options[:columns]
      columns.collect! { |c| c == "*" ? "#{@table}.*" : c }

      columns = columns.nil? || columns.empty? ? columns = "*" : columns.join(", ")
      conditions = options[:conditions] ? " #{options[:conditions]}"     : ""
      limit      = options[:limit]      ? " LIMIT #{options[:limit]}"    : ""
      offset     = options[:offset]     ? " OFFSET #{options[:offset]}"  : ""
      order      = options[:order]      ? " ORDER BY #{options[:order]}" : ""
      
      qry = "SELECT #{columns} FROM #{@table}#{conditions}#{order}#{limit}#{offset}"
      result = run_and_log_query(qry)
      retval = ResultSet.new(result, @adapter)

      case args.first
      when nil, :all
        retval
      when :first
        tmp = retval.next
        retval.close
        tmp
      end
    end

    def insert(columns, *values_ary)
      case @adapter
      when 'mysql'
        str = values_ary.collect do |values|
          values.collect { |v| v ? v.inspect : 'NULL' }.join(", ")
        end.join("), (")
        run_and_log_query("INSERT INTO #{@table} (#{columns.join(", ")}) VALUES(#{str})", true)
      when 'sqlite3'
        values_ary.each do |values|
          run_and_log_query("INSERT INTO #{@table} (#{columns.join(", ")}) VALUES(#{values.collect { |v| v ? v.inspect : 'NULL' }.join(", ")})", true)
        end
      end
    end

    def update(key, columns, values)
      str = columns.inject_with_index([]) do |arr, (col, i)|
        arr << "#{col} = #{values[i] ? values[i].inspect : 'NULL'}"
      end.join(", ")
      run_and_log_query("UPDATE #{@table} SET #{str} WHERE #{@primary_key} = #{key}", true)
    end

    def update_all(query)
      run_and_log_query("UPDATE #{@table} SET #{query}", true)
    end

    def delete(conditions)
      run_and_log_query("DELETE FROM #{@table} #{conditions}", true)
    end

    def insert_or_update(conditions, columns, values)
      # FIXME: use select(), dummy.
      res = run_and_log_query("SELECT #{@primary_key} FROM #{@table} #{conditions} LIMIT 1")
      key = res.next

      if key
        update(key, columns, values)
      else
        insert(columns, values)
      end
    end

    def replace(columns, *values_ary)
      case @adapter
      when 'mysql'
        str = values_ary.collect do |values|
          values.collect { |v| v ? v.inspect : 'NULL' }.join(", ")
        end.join("), (")
        run_and_log_query("REPLACE INTO #{@table} (#{columns.join(", ")}) VALUES(#{str})", true)
      when 'sqlite3'
        values_ary.each do |values|
          run_and_log_query("REPLACE INTO #{@table} (#{columns.join(", ")}) VALUES(#{values.collect { |v| v ? v.inspect : 'NULL' }.join(", ")})", true)
        end
      end
    end

    def create_table(name, columns, indices = [], auto_increment = false)
      columns.collect! { |c| c.sub("bigint", "int").sub("BIGINT", "INT") }  if @adapter == 'sqlite3'
      primary = columns.shift
      key     = primary.split[0]
      if auto_increment
        fields = case @adapter
          when 'sqlite3' then ["#{primary} PRIMARY KEY"] + columns
          when 'mysql'   then ["#{primary} NOT NULL AUTO_INCREMENT"] + columns + ["PRIMARY KEY (#{key})"]
        end
      else
        fields = [primary] + columns + ["PRIMARY KEY (#{key})"]
      end
      run_and_log_query("CREATE TABLE #{name} (#{fields.join(", ")})", true)

      indices.each do |column|
        run_and_log_query("CREATE INDEX #{name}_#{column}_idx ON #{name} (#{column})", true)
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
        run_and_log_query("DROP TABLE #{name}", true)
        true
      rescue SQLite3::SQLException, Mysql::Error
        false
      end
    end

    def drop_column(name)
      # i don't feel like supporting this for sqlite3 right now
      run_and_log_query({
        :mysql   => "ALTER TABLE #{@table} DROP COLUMN #{name}",
        :sqlite3 => nil
      }, true)
    end

    def columns(names)
      case @adapter
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
        res.close
        hsh
      end
    end

    def keys
      # FIXME: use select(), dummy.
      res = run_and_log_query("SELECT #{@primary_key} FROM #{@table} ORDER BY #{@primary_key}")
      retval = []
      res.each { |row| retval << row[0] }
      res.close
      retval
    end

    private
      def run_and_log_query(query, auto_close = false)
        Linkage.logger.debug("Resource (#{name}): #{query}")  if Linkage.logger
        res = case @adapter
          when 'sqlite3'
            qry = query.is_a?(Hash) ? query[:sqlite3] : query
            qry ? connection.query(qry) : nil
          when 'mysql'
            qry = query.is_a?(Hash) ? query[:mysql] : query
            qry ? connection.prepare(qry).execute : nil
        end
        res.close   if res && auto_close
        res
      end
  end
end
