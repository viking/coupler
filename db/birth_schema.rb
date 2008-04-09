SSN_POOL = %w{123456789 234567890 345678901 456789012 567890123}
NUMBERS  = %w{0 1 2 3 4 5 6 7 8 9}
def get_ssn
  if rand(10) == 1
    SSN_POOL[rand(SSN_POOL.length)]
  else
    (0..8).collect { |i| NUMBERS[rand(10)] }.join
  end
end

ActiveRecord::Schema.define do
  create_table :birth_all, {:primary_key => 'ID'} do |t|
    t.string 'MomSSN', :size => 9
  end
end
conn = ActiveRecord::Base.connection
100.times { |i| conn.execute("INSERT INTO birth_all VALUES(#{i+1}, #{get_ssn})") }
