
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

# Ensure we run in testproject directory.
$testProject1Dir = File.expand_path(File.dirname(__FILE__))

class TestProject1 < Test::Unit::TestCase
    def setup
	Dir.chdir($testProject1Dir) unless Dir.pwd == $testProject1Dir
	Rant.reset
    end
    def teardown
	capture_std do
	    assert_equal(Rant.run("force_clean"), 0)
	end
    end
    def test_run
	out, err = capture_std do
	    assert_equal(Rant.run("test_touch"), 0,
		"Exit code of rant should be 0.")
	end
	assert(err =~ /\[WARNING\]/,
	    "rant should print a warning because of enhance on non-existing task")
	Rant.reset
	assert(File.exist?("test_touch"),
	    "file test_touch should have been created")
	capture_std do
	    assert_equal(Rant.run("clean"), 0)
	end
	assert(!File.exist?("test_touch"))
    end
    def test_timedep
	capture_std do
	    assert_equal(Rant.run("create_target"), 0)
	end
	assert(File.exist?("target"))
	Rant.reset
	timeout
	capture_std do
	    assert_equal(Rant.run("create_dep"), 0)
	end
	assert(File.exist?("dep"))
	assert(Rant::Sys.uptodate?("dep", "target"),
	    "`create_target' was run before `create_dep'")
	timeout
	capture_std do
	    assert_equal(Rant.run("target"), 0)
	end
	assert(File.exist?("target"))
	assert(File.exist?("dep"))
	assert(Rant::Sys.uptodate?("target", "dep"),
	    "`target' should be newer than `dep'")
	t1 = File.mtime "target"
	Rant.reset
	timeout
	capture_std do
	    assert_equal(Rant.run("target"), 0)
	end
	assert_equal(t1, File.mtime("target"),
	    "`target' was already up to date")
    end
    def test_two_deps
	capture_std do
	    assert_equal(Rant.run("t2"), 0)
	end
	assert(File.exist?("t2"),
	    "file `t2' should have been built")
	assert(File.exist?("dep1"),
	    "dependancy `dep1' should have been built")
	assert(File.exist?("dep2"),
	    "depandancy `dep2' should have been build")
    end
    def test_duplicate
	capture_std do
	    assert_equal(Rant.run("duplicate"), 0)
	end
	assert(File.exist?("duplicate"))
	assert(File.exist?("duplicate1"),
	    "duplicate1 should have been created as side effect " +
	    "of running first task to build duplicate")
	assert(!File.exist?("duplicate2"),
	    "the second task to build duplicate should have " +
	    "been run, duplicate was already built")
    end
    def test_fallback
	capture_std do
	    assert_equal(Rant.run("fallback"), 0)
	end
	assert(File.exist?("fallback_"),
	    "should have been created as side-effect by fallback")
	assert(File.exist?("fallback"),
	    "second task for `fallback' should have been run")
    end
    def test_directory
	capture_std do
	    assert_equal(Rant.run("path"), 0)
	end
	assert(test(?d, "dir"),
	    "dir should have been created as prerequisite of dir/subdir")
	assert(test(?d, "dir/subdir"),
	    "dir/subdir should have been created as prerequisite of path")
    end
    def test_directory_postprocess
	capture_std do
	    assert_equal(Rant.run("dir/sub2"), 0)
	end
	assert(test(?d, "dir/sub2"),
	    "dir/sub2 should have been created by directory task")
	assert(test(?f, "dir/sub2/postprocess"),
	    "dir/sub2/postprocess should have been created by block supplied to directory task")
    end
    def test_directory_postprocess_2
	capture_std do
	    assert_equal(Rant.run("dir/subdir"), 0)
	end
	assert(test(?d, "dir/subdir"))
	assert(!File.exist?("dir/sub2"))
	capture_std do
	    assert_equal(Rant.run("dir/sub2"), 0)
	end
	assert(test(?f, "dir/sub2/postprocess"),
	    "dir/sub2/postprocess should have been created by block supplied to directory task")
    end
    def test_directory_pre_postprocess
	capture_std do
	    assert_equal(0, Rant.run("dir/sub3"))
	end
	assert(test(?d, "dir/sub3"))
	assert(test(?e, "dep1"), "dep1 is a prerequisite")
	assert(test(?e, "dir/sub3/postprocess"))
	old_mtime = File.mtime "dir/sub3"
	assert_equal(old_mtime, File.mtime("dep1"))
	timeout
	capture_std do
	    assert_equal(0, Rant.run("dir/sub3"))
	end
	assert_equal(old_mtime, File.mtime("dir/sub3"),
	    "no prerequisite requires update")
	assert_equal(old_mtime, File.mtime("dir/sub3/postprocess"))
	capture_std do
	    assert_equal(0, Rant.run(%w(-a dep1)))
	    assert(File.mtime("dep1") > old_mtime)
	    timeout
	    assert_equal(0, Rant.run("dir/sub3"))
	    assert(File.mtime("dir/sub3") > old_mtime)
	    assert(File.mtime("dir/sub3/postprocess") > old_mtime)
	end
    end
    def test_order
	capture_std do
	    assert_equal(Rant.run("order"), 0)
	end
	assert(File.exist?("order1"))
	assert(File.exist?("order2"))
	assert(File.mtime("order1") < File.mtime("order2"),
	    "tasks from same file should be run in definition order")
    end
    def test_enhance
	capture_std do
	    assert_equal(Rant.run("tbe"), 0)
	end
	assert(File.exist?("dep1"))
	assert(File.exist?("dep2"),
	    "dep2 was added as prerequisite to tbe by enhance")
	assert(File.exist?("tbe"))
	assert(File.exist?("tbe2"),
	    "tbe2 should be created by enhance for tbe")
	assert(test(?<, "tbe", "tbe2"),
	    "block added by enhance should run after \"normal\" block")
    end
    def test_enhance_nothing
	capture_std do
	    assert_equal(Rant.run("nothing"), 0,
		"enhance should create new task if no task with given name exists")
	end
    end
    def test_incremental_build
	capture_std do
	    assert_equal(Rant.run("inc"), 0)
	end
	assert(test(?f, "inc"))
	assert(test(?f, "incdep"))
	old_mtime = test(?M, "incdep")
	timeout
	capture_std do
	    assert_equal(Rant.run(%w(--force-run incdep)), 0,
		"--force-run should unconditionally run `incdep'")
	end
	assert(old_mtime < test(?M, "incdep"),
	    "incdep should have been updated by a forced run")
	capture_std do
	    assert_equal(Rant.run("inc"), 0)
	end
	assert(old_mtime < test(?M, "inc"),
	    "dependency `incdep' is newer, so `inc' should get rebuilt")
    end
    def test_lighttask
	capture_std do
	    assert_equal(Rant.run("lighttask"), 0)
	end
	assert(test(?e, "lt_target"),
	    "lt_target should get `touched' by lighttask")
    end
    def test_task_gen_one_arg
	capture_std do
	    assert_equal(Rant.run("task_one"), 0)
	end
	assert(test(?e, "one_target"),
	    "one_target should get `touched' by task_one")
	old_mtime = test(?M, "one_target")
	timeout
	capture_std do
	    assert_equal(Rant.run("task_one"), 0)
	end
	assert_equal(test(?M, "one_target"), old_mtime)
    end
    def test_task_gen_with_pre
	out, err = capture_std do
	    assert_equal(0, Rant.run("task_two"))
	end
	assert(test(?e, "one_target"),
	    "one_target should be created as prerequisite of task_two")
	assert_match(/task_two$/, out,
	    "task_two action prints task name")
    end
end
