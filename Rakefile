require 'rubygems'
require 'rake'
require 'spec'
require 'spec/rake/spectask'

task :spec
desc "Run all specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.spec_opts = ['--options', 'spec/spec.opts']
end
