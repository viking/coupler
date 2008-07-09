Story: transforming records
  As a researcher
  I want to transform records
  So that I can link them later 

Scenario: using the mysql specification
  Given the mysql specification
  When I transform the resources
  Then there should be a table named coupler_test with primary key ID
  And it should have column: ssn varchar(9)
  And it should have column: dob varchar(10)
  And it should have column: foo int(11)
  And it should have column: bar int(11)
  And every 75th ssn should be NULL 
  And every dob should have 10 days added 
  And every foo should be multiplied by 10 
  And every bar should be multiplied by 5 
