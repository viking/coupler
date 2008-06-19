require 'logger'
require 'yaml'
require 'enumerator'
require 'erb'
require 'optparse'

require 'rubygems'
require 'sqlite3'
require 'mysql'
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
require 'linkage/options'

module Linkage
  @@logger = nil
  def self.logger
    @@logger
  end

  def self.logger=(logger)
    @@logger = logger
  end
end
