
import 'rubydoc', 'rubypackage'

lib_files = FileList["lib/**/*.rb"]

gen RubyDoc do |g|
    g.files = lib_files + ["README"]
end

desc "Create packages for distribution."
gen RubyPackage, "wgrep" do |g|
    g.version "1.0.0"
    g.files FileList["{bin,lib,test}/**/*"] +
    	FileList["*"].no_dir.no_file("test_project.rb")
    g.summary "wgrep searches for a word in files"
    g.pkg_dir = "packages"
    g.package_task "pkg"
end

task :test do
    sys.cd "test" do
	sys.ruby "-I ../lib -S testrb tc_*.rb"
    end
end

task :clean do
    sys.rm_rf %w(doc packages)
end
