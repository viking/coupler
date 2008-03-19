require 'rubygems'
require 'spec'
require 'ruby-debug'
require 'yaml'

$:.unshift(File.dirname(__FILE__) + "/../lib")
require 'linkage'

Spec::Runner.configure do |config|
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
end
