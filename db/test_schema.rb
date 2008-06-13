require 'sqlite3'
ssn_pool = %w{123456789 234567890 345678901 456789012 567890123 678901234 789012345 890123456 901234567 012345678}
dob_pool = []
1.upto(25) do |i|
  dob_pool << "1970-01-%02d" % i
end

dbh = SQLite3::Database.new(File.dirname(__FILE__) + "/test.sqlite3")
dbh.query("CREATE TABLE records (ID int, ssn varchar(9), dob varchar(10), PRIMARY KEY(ID))")
100.times do |i|
  ssn = ssn_pool[i % ssn_pool.length]
  dob = dob_pool[i % dob_pool.length] 
  if i % 75 == 0
    ssn = "444444444"
    dob = nil
  end
  dbh.query("INSERT INTO records VALUES(?, ?, ?)", i+1, ssn, dob)
end
