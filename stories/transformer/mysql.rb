require File.dirname(__FILE__) + "/../helper"
require File.dirname(__FILE__) + "/steps"

with_steps_for :transformer do
  run File.dirname(__FILE__) + "/mysql.story"
end
