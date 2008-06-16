Story: linking records with sqlite3
  As a researcher
  I want to link records
  So that I can make a dataset

Scenario: running scenarios from the sqlite3 specification
  Given the sqlite3 specification
  When I run the scenarios
  Then it should create the ssn_linkage.csv file
  And every 75th record should match nothing
  And each record should match every 10th record with a score of 100 
  And there should be no extra scores
  And it should create the ssn_dob_linkage.csv file
  And every 75th record should match nothing
  And each record should match every 50th record with a score of 160
  And each record should match every 25th record with a score of 60
  And each record should match every 10th record with a score of 140
  And there should be no extra scores

Scenario: running scenarios while using an existing scratch database
  Given the sqlite3 specification
  And the option of using an existing scratch database 
  When I run the scenarios
  Then it should create the ssn_linkage.csv file
  And every 75th record should match nothing
  And each record should match every 10th record with a score of 100 
  And there should be no extra scores
  And it should create the ssn_dob_linkage.csv file
  And every 75th record should match nothing
  And each record should match every 50th record with a score of 160
  And each record should match every 25th record with a score of 60
  And each record should match every 10th record with a score of 140
  And there should be no extra scores