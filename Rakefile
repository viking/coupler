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

desc "Clean project"
task :clean do
  srcdir  = File.dirname(__FILE__) + "/ext"
  destdir = File.dirname(__FILE__) + "/lib/coupler"
  files =  Dir["#{srcdir}/*"].select  { |fn| fn =~ /(\.(o|so|bundle)|\/Makefile)$/ }
  files << Dir["#{destdir}/*"].select { |fn| fn =~ /\.(so|bundle)$/ }
  rm(files, :verbose => true)
end

desc "Build project"
task :build => :clean do
  srcdir  = File.dirname(__FILE__) + "/ext"
  destdir = File.dirname(__FILE__) + "/lib/coupler"
  if !File.exist?(File.join(srcdir, "Makefile"))
    prev = pwd
    cd srcdir
    system "ruby extconf.rb"
    cd prev
  end
  `make -C #{srcdir}`
  if File.exist?(fn = "#{srcdir}/cached_resource.so") || File.exist?(fn = "#{srcdir}/cached_resource.bundle")
    copy(fn, destdir)
  else
    raise "can't find cached_resource library"
  end
end

desc "Set up coupler environment"
task :bootstrap => :build do
  require 'rubygems/installer'
  %w{kwalify abstract erubis fastercsv}.each do |name|
      system "rm -fr vendor/#{name}*"
      version = all = Gem::Requirement.default
      dep = Gem::Dependency.new name, version
      specs_and_sources = Gem::SpecFetcher.fetcher.fetch dep, all
      specs_and_sources.sort_by { |spec,| spec.version }
      spec, source_uri = specs_and_sources.last
      gem_file_name = "#{spec.full_name}.gem"

      system "wget #{source_uri}/gems/#{gem_file_name} -O vendor/#{name}.gem"
      Gem::Installer.new("vendor/#{name}.gem").unpack("vendor/#{name}")
      rm "vendor/#{name}.gem"
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
