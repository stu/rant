import %w(rubytest rubydoc rubypackage)

lib_files = Dir["lib/**/*.rb"]
dist_files = lib_files + %w(rantfile.rb README test_project_rb1.rb) + Dir["{test,bin}/*"]

desc "Run unit tests."
gen RubyTest do |t|
    t.test_dir = "test"
    t.pattern = "tc_*.rb"
end

desc "Generate html documentation."
gen RubyDoc do |t|
    t.opts = %w(--title wgrep --main README README)
end

desc "Create packages."
gen RubyPackage, :wgrep do |t|
    t.version = "1.0.0"
    t.summary = "Simple grep program."
    t.files = dist_files
    t.bindir = "bin"
    t.executable = "wgrep"
    t.pkg_dir = "packages"
    t.package_task "pkg"
end

task :clean do
    sys.rm_rf %w(doc packages)
end
