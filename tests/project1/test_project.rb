
require 'test/unit'
require 'rant'

# Ensure we run in testproject directory.
dir = File.dirname(__FILE__)
cd(dir) unless Dir.pwd == dir

class TestProject1 < Test::Unit::TestCase
    def setup
	Rant.reset
    end
    def teardown
	assert_equal(Rant.run("force_clean"), 0)
    end
    def test_run
	assert_equal(Rant.run("test_touch"), 0,
	    "Exit code of rant should be 0.")
	Rant.reset
	assert(File.exist?("test_touch"),
	    "file test_touch should have been created")
	assert_equal(Rant.run("clean"), 0)
	assert(!File.exist?("test_touch"))
    end
    def test_timedep
	assert_equal(Rant.run("create_target"), 0)
	assert(File.exist?("target"))
	Rant.reset
	sleep 1
	assert_equal(Rant.run("create_dep"), 0)
	assert(File.exist?("dep"))
	sleep 1
	assert_equal(Rant.run("target"), 0)
	assert(File.exist?("target"))
	assert(File.exist?("dep"))
	assert(uptodate?("target", "dep"),
	    "`target' should be newer than `dep'")
	t1 = File.mtime "target"
	Rant.reset
	sleep 1
	assert_equal(Rant.run("target"), 0)
	assert_equal(t1, File.mtime("target"),
	    "`target' was already up to date")
    end
    def test_two_deps
	assert_equal(Rant.run("t2"), 0)
	assert(File.exist?("t2"),
	    "file `t2' should have been built")
	assert(File.exist?("dep1"),
	    "dependancy `dep1' should have been built")
	assert(File.exist?("dep2"),
	    "depandancy `dep2' should have been build")
    end
    def test_duplicate
	assert_equal(Rant.run("duplicate"), 0)
	assert(File.exist?("duplicate"))
	assert(File.exist?("duplicate1"),
	    "duplicate1 should have been created as side effect " +
	    "of running first task to build duplicate")
	assert(!File.exist?("duplicate2"),
	    "the second task to build duplicate should have " +
	    "been run, duplicate was already built")
    end
    def test_fallback
	assert_equal(Rant.run("fallback"), 0)
	assert(File.exist?("fallback_"),
	    "should have been created as side-effect by fallback")
	assert(File.exist?("fallback"),
	    "second task for `fallback' should have been run")
    end
    def test_directory
	assert_equal(Rant.run("path"), 0)
	assert(test(?d, "dir"),
	    "dir should have been created as prerequisite of dir/subdir")
	assert(test(?d, "dir/subdir"),
	    "dir/subdir should have been created as prerequisite of path")
    end
    def test_order
	assert_equal(Rant.run("order"), 0)
	assert(File.exist?("order1"))
	assert(File.exist?("order2"))
	assert(File.mtime("order1") < File.mtime("order2"),
	    "tasks from same file should be run in definition order")
    end
end
