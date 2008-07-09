require File.dirname(__FILE__) + "/../helper"
require File.dirname(__FILE__) + "/steps"
require 'fastercsv'

with_steps_for :coupler do
  run File.dirname(__FILE__) + "/sqlite3.story"
end
