module Coupler
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

    class RefillableSet < ResultSet
      attr_reader :parent, :page_size, :query, :type
      def initialize(parent, page_size, query)
        @parent    = parent
        @type      = parent.adapter
        @page_size = page_size
        @query     = query
        @closed    = false 
        @set       = nil
        @offset    = 0
      end

      alias :next_without_refilling :next
      def next
        return nil  if @closed
        refill!     if @set.nil?

        record = next_without_refilling
        if record.nil?
          refill!
          record = next_without_refilling
          close if record.nil?
        end
        record
      end

      private
        def refill!
          @set.close  if @set
          @set = @parent.send(:run_and_log_query, "#{@query} LIMIT #{@page_size} OFFSET #{@offset}")
          @offset += @page_size
        end
    end

    class InsertBuffer
      def initialize(parent, page_size, columns)
        @parent    = parent
        @columns   = columns
        @page_size = page_size
        @buffer    = Buffer.new(page_size)
      end

      def <<(record)
        flush!  if @buffer.full?
        @buffer << record
      end

      def flush!
        unless @buffer.empty?
          @parent.insert(@columns, *@buffer.data)
          @buffer.flush!
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

    attr_reader :name, :configuration, :table, :primary_key, :adapter

    def initialize(spec, options)
      @options = options
      @name    = spec['name']
      if @@resources.keys.include?(@name)
        raise "duplicate name"
      else
        @@resources[@name] = self
      end
      @configuration = spec['connection']
      @adapter = @configuration['adapter']

      if spec['table']
        @table = spec['table']['name']
        @primary_key = spec['table']['primary key']
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
      options = args.extract_options!
      refill  = options.delete(:auto_refill)
      qry     = construct_query(options)
      if refill
        RefillableSet.new(self, @options.db_limit, qry)
      else
        result  = run_and_log_query(qry)
        retval  = ResultSet.new(result, @adapter)

        case args.first
        when nil, :all
          retval
        when :first
          tmp = retval.next
          retval.close
          tmp
        end
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

    def insert_buffer(columns)
      InsertBuffer.new(self, @options.db_limit, columns)
    end

    def update(key, columns, values)
      str = columns.inject_with_index([]) do |arr, (col, i)|
        arr << "#{col} = #{values[i] ? values[i].inspect : 'NULL'}"
      end.join(", ")
      run_and_log_query("UPDATE #{@table} SET #{str} WHERE #{@primary_key} = #{key}", true)
    end

    # ugly ass template
    @@multi_update_template = Erubis::Eruby.new(<<EOF)
UPDATE <%= @table %> SET
<% columns.each_with_index do |colname, i| -%>
  <%= colname %> = CASE <%= @primary_key %>
  <% keys.each_with_index do |key, j| -%>
    WHEN <%= key %> THEN <%= (v = values[j][i]) ? v.inspect : "NULL" %>
  <% end -%>
  <%= (i == columns.length-1) ? "END" : "END," %>
<% end -%>
WHERE <%= @primary_key %> IN (<%= keys.join(", ") %>)
EOF
    def multi_update(keys, columns, values)
      # I don't know about this, to be honest.
      run_and_log_query(@@multi_update_template.result(binding), true)
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
      columns = columns.dup
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

      indices.each do |arg|
        if arg.is_a?(Array)
          columns = arg.join(", ")
          cname   = arg.join("_")
        else
          columns = arg
          cname   = arg
        end
        run_and_log_query("CREATE INDEX #{name}_#{cname}_idx ON #{name} (#{columns})", true)
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
      def construct_query(options)
        # FIXME: put WHERE automatically into conditions, dummy.
        columns = options[:columns]
        columns.collect! { |c| c == "*" ? "#{@table}.*" : c }

        columns = columns.nil? || columns.empty? ? columns = "*" : columns.join(", ")
        conditions = options[:conditions] ? " #{options[:conditions]}"     : ""
        limit      = options[:limit]      ? " LIMIT #{options[:limit]}"    : ""
        offset     = options[:offset]     ? " OFFSET #{options[:offset]}"  : ""
        order      = options[:order]      ? " ORDER BY #{options[:order]}" : ""
        
        "SELECT #{columns} FROM #{@table}#{conditions}#{order}#{limit}#{offset}"
      end

      def run_and_log_query(query, auto_close = false)
        Coupler.logger.debug("Resource (#{name}): #{query}")  if Coupler.logger
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
