require File.dirname(__FILE__) + "/../helper"
require File.dirname(__FILE__) + "/steps"
require 'fastercsv'

Story "linking records",
  %{As a researcher
  I want to link records
  So that I can make a dataset to analyze}, :steps_for => [:coupler, :runner] do

  %w{mysql sqlite3}.each do |adapter|
    Scenario "running in #{adapter} with csv output" do
      Given "the people specification"
      And   "that I want to use the #{adapter} adapter"
      And   "that I want CSV output files"
      When  "I transform the resources"
      And   "I run the scenarios"
      Then  "it should create first_rule.csv"
      And   "each record should match every 8th record with a score of 100" 
      And   "it should create second_rule.csv"
      And   "each record should match every 12th record with a score of 200"
    end
  end
end
