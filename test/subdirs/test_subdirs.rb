
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

# Ensure we run in testproject directory.
$testSubdirsDir = File.expand_path(File.dirname(__FILE__))

class TestSubdirs < Test::Unit::TestCase
    def setup
	Dir.chdir($testSubdirsDir) unless Dir.pwd == $testSubdirsDir
	Rant.reset
    end
    def teardown
	capture_std do
	    assert_equal(Rant.run("clean"), 0)
	end
	created = Dir["**/*t"]
	assert(created.empty?)
    end
    def test_load
	capture_std do
	    assert_equal(0, Rant.run("-T"))
	end
    end
    def test_sub_dep
	capture_std do
	    assert_equal(0, Rant.run("t"))
	end
	assert(test(?f, "sub1/t"),
	    "t depends on sub1/t")
	assert(test(?f, "t"))
    end
    def test_sub_dep2
	capture_std do
	    assert_equal(0, Rant.run("2t"))
	end
	assert(test(?f, "sub2/t"))
	assert(test(?f, "2t"))
	assert(!test(?e, "sub1/t"))
    end
    def test_sub_task_from_commandline
	capture_std do
	    assert_equal(0, Rant.run("sub1/t"))
	end
	assert(test(?f, "sub1/t"))
	assert(!test(?e, "t"))
	capture_std do
	    assert_equal(0, Rant.run("sub1/clean"))
	end
	assert(!test(?f, "sub1/t"))
    end
    def test_root_dep
	capture_std do
	    assert_equal(0, Rant.run("sub1/rootdep.t"))
	end
	assert(test(?f, "subdep.t"))
	assert(test(?f, "sub1/rootdep.t"))
    end
    def test_sub_sub_dep
	capture_std do
	    assert_equal(0, Rant.run("sub2/subdep.t"))
	end
	assert(test(?f, "sub2/subdep.t"))
	assert(test(?f, "sub2/sub/rootdep.t"))
    end
    def test_sub_sub_rootref
	capture_std do
	    assert_equal(0, Rant.run("sub2/sub/rootref.t"))
	end
	assert(test(?f, "t"))
	assert(test(?f, "sub2/sub/rootref.t"))
    end
    def test_root_sub_sub_rootref
	capture_std do
	    assert_equal(0, Rant.run("sub_sub"))
	end
	assert(test(?f, "sub_sub.t"))
	assert(test(?f, "sub2/sub/rootref.t"))
	assert(test(?f, "t"))
    end
end
