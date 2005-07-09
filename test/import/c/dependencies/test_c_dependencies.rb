
require 'test/unit'
require 'tutil'

$testImportCDepDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportCDependencies < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testImportCDepDir
	@manifest = %w(
	    test_c_dependencies.rb Rantfile hello.c foo.h bar.h
	    include include/foo.h include/sub include/sub/sub.h
	    src src/abc src/abc.c src/bar.c
	)
	@manifest << "include/with space.h"
    end
    def teardown
	Dir.chdir $testImportCDepDir
	FileUtils.rm_f "c_dependencies"
	FileUtils.rm_rf Dir["*.t"]
	@manifest.each { |f|
	    assert(test(?e, f), "#{f} missing")
	}
    end
    def test_hello_c
	assert_rant("hello.t")
	assert(test(?f, "hello.t"))
	assert(test(?f, "c_dependencies"))
	out, err = assert_rant("hello.t")
	assert(out.strip.empty?)
	assert(err.strip.empty?)
	timeout
	FileUtils.touch "foo.h"
	old_mtime = File.mtime "hello.t"
	assert_rant("hello.t")
	assert(File.mtime("hello.t") > old_mtime)
	old_mtime = File.mtime("hello.t")
	timeout
	out, err = assert_rant("hello.t")
	assert(out.strip.empty?)
	assert(err.strip.empty?)
	FileUtils.rm "c_dependencies"
	out, err = assert_rant("hello.t")
	assert(!out.strip.empty?)
	assert(err.strip.empty?)
	assert_equal(old_mtime, File.mtime("hello.t"))
    end
    def test_bar_c
	assert_rant("deps=2", "bar.t")
	assert(test(?f, "bar.t"))
	assert(test(?f, "deps2.t"))
	cdeps_mtime = File.mtime "deps2.t"
	FileUtils.rm "bar.t"
	assert_rant("deps=2", "bar.t")
	assert(test(?f, "bar.t"))
	assert_equal(cdeps_mtime, File.mtime("deps2.t"))
	old_mtime = File.mtime "bar.t"
	timeout
	FileUtils.touch "src/abc.c"
	assert_rant("deps=2", "bar.t")
	assert_equal(old_mtime, File.mtime("bar.t"))
	timeout
	FileUtils.touch "include/with space.h"
	assert_rant("deps=2", "bar.t")
	assert(File.mtime("bar.t") > old_mtime)
    end
    def test_bar_c_deps3
	assert_rant("deps=3", "bar.t")
	assert(test(?f, "bar.t"))
	assert(test(?f, "deps3.t"))
	old_mtime = File.mtime("bar.t")
	timeout
	FileUtils.touch "src/abc"
	assert_rant("deps=3", "bar.t")
	assert(File.mtime("bar.t") > old_mtime)
	old_mtime = File.mtime "bar.t"
	timeout
	FileUtils.touch "src/abc.c"
	assert_rant("deps=3", "bar.t")
	assert(File.mtime("bar.t") > old_mtime)
	old_mtime = File.mtime "bar.t"
	timeout
	FileUtils.touch "foo.h"
	assert_rant("deps=3", "bar.t")
	assert(File.mtime("bar.t") > old_mtime)
	assert_rant("autoclean")
	%w(a.t hello.t bar.t c_dependencies deps2.t deps3.t).each { |f|
	    assert(!test(?e, f), "#{f} should get unlinked by AutoClean")
	}
    end
    def test_rant_import_hello_c
        run_import("-q", "--auto", "ant.t")
        assert_exit
        assert(test(?f, "ant.t"))
        run_ruby("ant.t", "hello.t")
        assert_exit
	assert(test(?f, "hello.t"))
	assert(test(?f, "c_dependencies"))
        out = run_ruby("ant.t", "hello.t")
	assert(out.strip.empty?)
	open "ant.t" do |f|
	    requires = extract_requires(f)
	    requires.each { |fn|
		assert_no_match(/^rant\//, fn,
		    "#{fn} should be inlined by rant-import")
	    }
	end
    end
end
