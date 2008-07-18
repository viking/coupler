require 'rubygems'
require 'sqlite3'
require 'mysql'
require 'enumerator'

pool = {
  'foo'   => %w{123456789 234567891 345678912 444444444 567891234 678912345 789123456 891234567 999999999},
  'pants' => %w{khakis jeans shorts trunks speedo skirt},
  'shirt' => %w{polo tshirt blouse sweater bikini tanktop}
}

mydbh = Mysql.new('localhost', 'coupler', 'coupler', 'coupler_test_records')
%w{leetsauce weaksauce mayhem}.each do |name|
  sqlfile = File.dirname(__FILE__) + "/#{name}.sqlite3"
  File.delete(sqlfile)  if File.exist?(sqlfile)
  mydbh.query("DROP TABLE IF EXISTS #{name}")
  sldbh = SQLite3::Database.new(sqlfile)

  columns, types = case name
    when 'leetsauce'
      [%w{id foo zoidberg nixon}, %w{int varchar(9) int int}]
    when 'weaksauce'
      [%w{id foo nixon}, %w{int varchar(9) int}]
    when 'mayhem'
      [%w{id pants shirt}, %w{int varchar(10) varchar(10)}]
  end
  fields = columns.enum_for(:each_with_index).collect { |c, i| "#{c} #{types[i]}"}.join(", ")
  mydbh.query("CREATE TABLE #{name} (#{fields}, primary key(id))")
  sldbh.query("CREATE TABLE #{name} (#{fields}, primary key(id))")
  100.times do |i|
    values = columns.collect do |column|
      if (p = pool[column])
        p[rand(p.length)].inspect
      else
        column == 'id' ? i : rand(100)
      end
    end
    [mydbh, sldbh].each do |dbh|
      dbh.query "INSERT INTO #{name} (#{columns.join(",")}) VALUES(#{values.join(",")})" 
    end
  end
end
