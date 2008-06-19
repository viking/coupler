Story: linking records
  As a researcher
  I want to link records
  So that I can make a dataset

Scenario: running scenarios from the mysql specification with csv output
  Given the mysql specification
  And that I want CSV output files
  When I run the scenarios
  Then it should create the ssn_coupler.csv file
  And every 75th record should match nothing
  And each record should match every 10th record with a score of 100 
  And there should be no extra scores
  And it should create the ssn_dob_coupler.csv file
  And every 75th record should match nothing
  And each record should match every 50th record with a score of 160
  And each record should match every 25th record with a score of 60
  And each record should match every 10th record with a score of 140
  And there should be no extra scores

Scenario: running scenarios from the mysql specification with no csv output
  Given the mysql specification
  When I run the scenarios
  Then it should store scores in the ssn_coupler table
  And every 75th record should match nothing
  And each record should match every 10th record with a score of 100 
  And there should be no extra scores
  And it should store scores in the ssn_dob_coupler table
  And every 75th record should match nothing
  And each record should match every 50th record with a score of 160
  And each record should match every 25th record with a score of 60
  And each record should match every 10th record with a score of 140
  And there should be no extra scores

