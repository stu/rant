# Rakefile for the rant project.

$:.unshift(File.join(Dir.pwd, "lib"))

require 'rubygems'
require 'rant'	# contains VERSION
Gem::manage_gems
require 'rake/gempackagetask'
require 'rake/testtask'
require 'rake/clean'

task :default => :package

lib_files = FileList['lib/**/*.rb'].exclude(/\.svn/)
doc_files = lib_files
rdoc_opts = %w(-c UTF-8 --title Rant --main lib/rant.rb)
all_tests = FileList['tests/test_*.rb']

GEM_SPEC = Gem::Specification.new do |s|
    s.name		=    "rant"
    s.version		=    Rant::VERSION
    s.author		=    "Stefan Lang"
    s.email		=    "langstefan@gmx.at"
    #s.homepage
    #s.rubyforge_project    =    "rant"
    #s.platform        =    Gem::Platform::RUBY
    s.summary		=    "Another build tool for C# and Ruby."
    s.description		=    <<-EOD
    	Rant a build tool for small to midsized C# projects
	and Ruby projects. It was inspired by Rake and Ant.
        EOD
	s.files		=    Dir.glob("{bin,lib,tests,pkg}/**/*").delete_if { |path|
	                        path.include?(".svn")
	                }
			#s.files = Dir["**/*"]
    s.require_path	=    "lib"
    s.autorequire	=    "rant/rantlib"
    # currently we don't include unit tests
    #s.test_files    =    all_tests.to_a
    s.has_rdoc		=    true
    s.rdoc_options		=    rdoc_opts
    #s.extra_rdoc_files    =    ["README"]
    s.bindir		=    "bin"
    s.executables	=    ["rant"]
    #s.executables    =    Dir["bin/*"].find_all { |path| File.file?(path) }
    s.default_executable	=    "rant"
end

Rake::GemPackageTask.new(GEM_SPEC) do |pkg|
    pkg.need_tar = true
    pkg.need_zip = false
end

task :test do
    libdir = File.join(pwd, "lib")
    cd("tests") {
	#rm_rf "testdata"
	#mkdir "testdata"
	ruby "-I#{libdir} -S testrb " + Dir["test_*.rb"].join(' ')
	cd("project1") {
	    ruby "-I#{libdir} -S testrb test_project.rb"
	}
    }
end

desc "Generate RDoc documentation."
file "doc" => doc_files do |t|
    touch "doc" if test ?d, "doc"
    sh "rdoc #{rdoc_opts.join(' ')} lib"
end

CLEAN << "doc"
