require 'fileutils'
require 'rubygems'
require 'rake'
require 'spec'
require 'spec/rake/spectask'
include FileUtils

desc "Run all specs"
task :spec => :build
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = ['--options', 'spec/spec.opts']
end

desc "Run all stories"
task :stories, :story, :needs => [:build, "db:test:prepare"] do |t, args|
  require 'stories/helper'
  if args.story
    files = Dir["stories/#{args.story}/**/*.rb"]
    files.select { |f| f =~ /steps\.rb$/ }.each { |f| files.delete(f) }
    files.each { |f| load(f) }
  else
    load("stories/all.rb")
  end
end

desc "Build project"
task :build do
  srcdir  = File.dirname(__FILE__) + "/ext"
  destdir = File.dirname(__FILE__) + "/lib/coupler"
  if !File.exist?(File.join(srcdir, "Makefile"))
    prev = pwd
    cd srcdir
    load File.join(srcdir, "extconf.rb")
    cd pwd
  end
  `make -C #{srcdir}`
  if File.exist?(fn = "#{srcdir}/cached_resource.so") || File.exist?(fn = "#{srcdir}/cached_resource.bundle")
    copy(fn, destdir)
  else
    raise "can't find cached_resource library"
  end
end

namespace :db do
  namespace :test do
    desc 'Prepare the test databases and load the schema'
    task :prepare do
      load('db/test/schema.rb')
    end
  end
end
