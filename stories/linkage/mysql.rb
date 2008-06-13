require File.dirname(__FILE__) + "/../helper"
require File.dirname(__FILE__) + "/steps"
require 'fastercsv'

with_steps_for :linkage do
  run File.dirname(__FILE__) + "/mysql.story"
end
