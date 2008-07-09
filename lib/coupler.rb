require 'logger'
require 'yaml'
require 'enumerator'
require 'erb'
require 'optparse'

require 'rubygems'
require 'sqlite3'
require 'mysql'
require 'fastercsv'
require 'erubis'

require 'progress'
require 'coupler/extensions'
require 'coupler/resource'
require 'coupler/transformer'
require 'coupler/scenario'
require 'coupler/runner'
require 'coupler/cache'
require 'coupler/matchers'
require 'coupler/scores'
require 'coupler/options'

module Coupler
  @@logger = nil
  def self.logger
    @@logger
  end

  def self.logger=(logger)
    @@logger = logger
  end
end
