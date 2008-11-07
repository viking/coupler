require 'logger'
require 'yaml'
require 'enumerator'
require 'optparse'

# vendor libraries
%w(rubygems sqlite3 mysql fastercsv abstract erubis kwalify).each do |dependency|
  begin
    dir = File.expand_path(File.dirname(__FILE__) + "/../vendor/#{dependency}/lib")
    $: << dir   if File.directory?(dir)
    require dependency
  rescue LoadError
    abort "Unable to load #{dependency}"
  end
end

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
require 'coupler/matcher'
require 'coupler/options'
require 'coupler/resource'
require 'coupler/runner'
require 'coupler/scenario'
require 'coupler/scores'
require 'coupler/specification'
require 'coupler/transformer'
require 'coupler/cached_resource'
