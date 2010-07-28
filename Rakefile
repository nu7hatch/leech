require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "leech"
    gem.summary = %Q{Simple TCP client/server framework with commands handling}
    gem.description = %Q{Leech is simple TCP client/server framework. Server is
    similar to rack. It allows to define own handlers for received text commands. }
    gem.email = "kriss.kowalik@gmail.com"
    gem.homepage = "http://github.com/kriss/leech"
    gem.authors = ["Kriss Kowalik"]
    gem.add_development_dependency "rspec", ">= 1.2.9"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

task :default => :spec

begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    version   = File.exist?('VERSION') ? File.read('VERSION') : ""
    title     = "Leech #{version}"
    t.files   = ['lib/**/*.rb', 'README*']
    t.options = ['--title', title, '--markup', 'markdown', '--files', 'CHANGELOG.md,TODO.md']
  end
rescue LoadError
  task :yard do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end
