require 'logger'
require 'yaml'
require 'enumerator'
require 'erb'

require 'rubygems'
require 'sqlite3'
require 'mysql'
require 'ruby-debug'
require 'fastercsv'

require 'progress'
require 'linkage/extensions'
require 'linkage/resource'
require 'linkage/transformer'
require 'linkage/scenario'
require 'linkage/runner'
require 'linkage/cache'
require 'linkage/matchers'
require 'linkage/scores'

module Linkage
  NUMBER_PER_FETCH = 10000
  
  @@logger = nil
  def self.logger
    @@logger
  end

  def self.logger=(logger)
    @@logger = logger
  end
end
