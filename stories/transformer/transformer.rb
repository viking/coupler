require File.dirname(__FILE__) + "/../helper"
require File.dirname(__FILE__) + "/steps"

Story "transforming records", 
  %{As a researcher
    I want to transform records
    So that I can link them later}, :steps_for => [:coupler, :transformer] do

  %w{mysql sqlite3}.each do |adapter|
    Scenario "transforming in #{adapter}" do
      Given "the sauce specification"
      And   "that I want to use the #{adapter} adapter"
      When  "I transform the resources"
      Then  "there should be a scratch table named leetsauce with primary key id"
      And   "it should have column: id int"
      And   "it should have column: foo varchar(9)"
      And   "it should have column: bar int"
      And   "it should have column: zoidberg int"
      And   "it should have column: farnsworth varchar(10)"
      And   "foo should have been transformed properly"
      And   "bar should have been transformed properly"
      And   "wong should have been renamed to farnsworth"
      And   "zoidberg should not have been transformed"
      And   "there should be a scratch table named weaksauce with primary key id"
      And   "it should have column: id int"
      And   "it should have column: foo varchar"
      And   "it should have column: nixon int"
      And   "foo should have been transformed properly"
      And   "nixon should not have been transformed"
      And   "there should be a scratch table named mayhem with primary key id"
      And   "it should have column: id int"
      And   "it should have column: pants varchar"
      And   "it should have column: shirt varchar"
      And   "pants should not have been transformed"
      And   "shirt should not have been transformed"
    end
  end
end
