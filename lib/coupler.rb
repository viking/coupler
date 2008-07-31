require 'logger'
require 'yaml'
require 'enumerator'
require 'optparse'

require 'rubygems'
require 'sqlite3'
require 'mysql'
require 'fastercsv'
require 'erubis'

require 'buffer'

module Coupler
  @logger = nil
  @runner = nil

  def self.logger
    @logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.runner
    @runner ||= Runner.new
  end

  def self.specification
    runner.specification
  end

  def self.options
    runner.options
  end
end

require 'coupler/extensions'
require 'coupler/matchers'
require 'coupler/options'
require 'coupler/resource'
require 'coupler/runner'
require 'coupler/scenario'
require 'coupler/scores'
require 'coupler/specification'
require 'coupler/transformer'
require 'coupler/cached_resource'
