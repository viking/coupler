require File.dirname(__FILE__) + "/../helper"
require File.dirname(__FILE__) + "/steps"

with_steps_for :family do
  run File.dirname(__FILE__) + "/family.story"
end

