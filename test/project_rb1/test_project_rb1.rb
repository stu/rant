
require 'test/unit'
require 'rant/rantlib'

$testProjectRb1Dir = File.expand_path(File.dirname(__FILE__))

class TestProjectRb1 < Test::Unit::TestCase
    def setup
	@manifest = %w(bin lib test bin/wgrep lib/wgrep.rb
	    test/text test/tc_wgrep.rb README test_project_rb1.rb
	    rantfile.rb)
	# Ensure we run in test directory.
	Dir.chdir($testProjectRb1Dir) unless Dir.pwd == $testProjectRb1Dir
    end
    def teardown
	assert_equal(Rant.run(%w(clean)), 0)
	manifest = @manifest.dup
	Dir["**/*"].each { |e|
	    assert(manifest.reject! { |mf| mf == e } ,
		"#{e} shouldn't exist after clean")
	}
	manifest.each { |e|
	    assert(false, "#{e} missing")
	}
    end
    def test_doc
	assert_equal(Rant.run(%w(doc)), 0)
	assert(test(?d, "doc"),
	    "RDoc task should generate dir `doc'")
	assert(test(?f, "doc/index.html"),
	    "doc/index.html should exist after `doc'")
	fl = Dir["doc/files/**/*"]
	assert(fl.find { |f| f =~ /wgrep/ },
	    "lib/wgrep.rb should get documented")
	assert(fl.find { |f| f =~ /README/ },
	    "README should be in html docs")
    end
    def test_test
	assert_equal(Rant.run(%w(test)), 0)
    end
    def test_package
	assert_equal(Rant.run(%w(pkg)), 0)
	assert(test(?d, "packages"),
	    "task `pkg' should create dir `packages'")
	have_tar = !`tar --help`.empty?
	have_zip = !`zip -help`.empty?
	have_gem = false
	pkg_base = "packages/wgrep-1.0.0"
	begin
	    require 'rubygems'
	    have_gem = true
	rescue LoadError
	end
	if have_tar
	    assert(test(?f, pkg_base + ".tar.gz"),
		"tar is available, so a tar.gz should have been built")
	else
	    puts "*** tar not available ***"
	end
	if have_zip
	    assert(test(?f, pkg_base + ".zip"),
		"zip is available, so a zip should have been built")
	else
	    puts "*** zip not available ***"
	end
	if have_gem
	    assert(test(?f, pkg_base + ".gem"),
		"gem is available, so a gem should have been built")
	else
	    puts "*** gem not available ***"
	end
    end
end
