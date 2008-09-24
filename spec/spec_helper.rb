require 'rubygems'
require 'spec'
require 'yaml'

# optionally get ruby-debug
begin
  require 'ruby-debug'
rescue LoadError
end

# get collections/sequenced_hash
dir = File.expand_path(File.dirname(__FILE__) + "/../vendor/collections/lib")
$: << dir   if File.directory?(dir)
require 'collections/sequenced_hash'

$:.unshift(File.dirname(__FILE__) + "/../lib")
require 'coupler'

logger = Logger.new(File.dirname(__FILE__) + "/../log/test.log")
logger.level = Logger::DEBUG
Coupler.logger = logger

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
