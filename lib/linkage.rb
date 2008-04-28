require 'csv'
require 'weakref'
require 'progress'

require 'rubygems'
require 'active_support'
require 'sqlite3'
require 'mysql'
require 'arrayfields'
require 'ruby-debug'

require 'linkage/extensions'
require 'linkage/resource'
require 'linkage/transformer'
require 'linkage/scenario'
require 'linkage/runner'
require 'linkage/cache'

module Linkage
  @@logger = nil
  
  def self.logger
    @@logger
  end

  def self.logger=(logger)
    @@logger = logger
  end
end
