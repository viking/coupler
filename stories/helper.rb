require 'rubygems'
require 'spec'
require 'spec/story'
require 'ruby-debug'
require 'yaml'
require 'erb'

$:.unshift(File.dirname(__FILE__) + "/../lib")
require 'linkage'

logger = Logger.new(File.dirname(__FILE__) + "/../log/story.log")
logger.level = Logger::INFO
Linkage.logger = logger 
