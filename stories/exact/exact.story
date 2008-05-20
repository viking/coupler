Story: creating records that exactly match
  As a researcher
  I want to link records that exactly match

Scenario: running a scenario
  When I run the exact specification
  Then it should create the ssn_linkage.csv file
  And each record should match every 10th record with a score of 100 
  And there should be no extra scores
  And it should create the ssn_dob_linkage.csv file
  And each record should match every 50th record with a score of 160
  And each record should match every 25th record with a score of 60
  And each record should match every 10th record with a score of 140
  And there should be no extra scores
