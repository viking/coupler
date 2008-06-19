require 'rubygems'
require 'spec'
require 'spec/story'
require 'ruby-debug'
require 'yaml'
require 'erb'

$:.unshift(File.dirname(__FILE__) + "/../lib")
require 'coupler'

logger = Logger.new(File.dirname(__FILE__) + "/../log/story.log")
logger.level = Logger::INFO
Coupler.logger = logger 
