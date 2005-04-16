
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

# Ensure we run in testproject directory.
$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestSource < Test::Unit::TestCase
    def setup
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
	capture_std do
	    assert_equal(0, Rant.run("clean"))
	end
    end
    def test_task_for_source
	capture_std do
	    assert_equal(0, Rant.run("auto.t"))
	end
	assert(test(?f, "auto.rf"))
	assert(test(?f, "auto.t"))
    end
end
