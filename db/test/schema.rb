require 'rubygems'
require 'sqlite3'
require 'mysql'
require 'enumerator'

pool = {
  'foo' => %w{123456789 234567891 345678912 444444444 567891234 678912345 789123456 891234567 999999999},
  'wong' => %w{ichi ni san yon go roku nana hachi kyuu juu},
  'brannigan' => %w{uno dos tres cuatro cinco seis siete ocho nueve dies},
  'pants' => %w{khakis jeans shorts trunks speedo skirt},
  'shirt' => %w{polo tshirt blouse sweater bikini tanktop},
  'first_name' => %w{Ender Valentine Peter Alai Shen Petra Bean Dink},
  'last_name' => %w{Potter Granger Weasley Longbottom},
  'date_of_birth' => %w{1980-07-31 1955-10-25 1985-10-25 1982-03-14 1809-02-12 2015-10-25}
}

mydbh = Mysql.new('localhost', 'coupler', 'coupler', 'coupler_test_records')
%w{leetsauce weaksauce mayhem people}.each do |name|
  sqlfile = File.dirname(__FILE__) + "/#{name}.sqlite3"
  File.delete(sqlfile)  if File.exist?(sqlfile)
  mydbh.query("DROP TABLE IF EXISTS #{name}")
  sldbh = SQLite3::Database.new(sqlfile)

  columns, types = case name
    when 'leetsauce'
      [%w{id foo zoidberg nixon wong}, %w{int varchar(9) int int varchar(10)}]
    when 'weaksauce'
      [%w{id foo nixon brannigan}, %w{int varchar(9) int varchar(10)}]
    when 'mayhem'
      [%w{id pants shirt}, %w{int varchar(10) varchar(10)}]
    when 'people'
      [%w{id first_name last_name date_of_birth}, %w{int varchar(20) varchar(20) date}]
  end
  fields = columns.enum_for(:each_with_index).collect { |c, i| "#{c} #{types[i]}"}.join(", ")
  mydbh.query("CREATE TABLE #{name} (#{fields}, primary key(id))")
  sldbh.query("CREATE TABLE #{name} (#{fields}, primary key(id))")
  100.times do |i|
    values = columns.collect do |column|
      if (p = pool[column])
        if %w{first_name last_name date_of_birth}.include?(column)
          p[i % p.length].inspect
        else
          p[rand(p.length)].inspect
        end
      else
        column == 'id' ? i+1 : rand(100)
      end
    end
    [mydbh, sldbh].each do |dbh|
      dbh.query "INSERT INTO #{name} (#{columns.join(",")}) VALUES(#{values.join(",")})" 
    end
  end
end
