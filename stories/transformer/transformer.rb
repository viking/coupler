require File.dirname(__FILE__) + "/../helper"
require File.dirname(__FILE__) + "/steps"

Story "transforming records", 
  %{As a researcher
    I want to transform records
    So that I can link them later}, :steps_for => [:coupler, :transformer] do

  %w{mysql sqlite3}.each do |adapter|
    Scenario "transforming in #{adapter}" do
      Given "the sauce specification"
      Given "that I want to use the #{adapter} adapter"
      When  "I transform the resources"
      Then  "there should be a scratch table named leetsauce with primary key id"
      Then  "it should have column: id int"
      Then  "it should have column: foo varchar(9)"
      Then  "it should have column: bar int"
      Then  "it should have column: zoidberg int"
      Then  "it should have column: farnsworth varchar(30)"
      Then  "foo should have been transformed properly"
      Then  "bar should have been transformed properly"
      Then  "wong should have been renamed to farnsworth"
      Then  "zoidberg should not have been transformed"
      Then  "there should be a scratch table named weaksauce with primary key id"
      Then  "it should have column: id int"
      Then  "it should have column: foo varchar"
      Then  "it should have column: nixon int"
      Then  "foo should have been transformed properly"
      Then  "nixon should not have been transformed"
      Then  "there should be a scratch table named mayhem with primary key id"
      Then  "it should have column: id int"
      Then  "it should have column: pants varchar"
      Then  "it should have column: shirt varchar"
      Then  "pants should not have been transformed"
      Then  "shirt should not have been transformed"
    end
  end
end
