require 'fileutils'
require 'rubygems'
require 'rake'
require 'spec'
require 'spec/rake/spectask'

desc "Run all specs"
task :spec => :build
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = ['--options', 'spec/spec.opts']
end

desc "Run all stories"
task :stories => [:build, "db:test:prepare"] do
  load("stories/all.rb")
end

desc "Build project"
task :build do
  srcdir  = File.dirname(__FILE__) + "/ext"
  destdir = File.dirname(__FILE__) + "/lib/linkage"
  `make -C #{srcdir}`
  if File.exist?(fn = "#{srcdir}/cache.so") || File.exist?(fn = "#{srcdir}/cache.bundle")
    FileUtils.copy(fn, destdir)
  else
    raise "can't find cache library"
  end
end

namespace :db do
  namespace :test do
    desc 'Prepare the test databases and load the schema'
    task :prepare do
      require 'sqlite3'
      files = Dir['db/*_schema.rb']
      files.each do |file|
        name = File.basename(file, "_schema.rb")
        db   = "db/#{name}.sqlite3"
        File.delete(db) if File.exist?(db)
        load(file)
      end
    end
  end
end
