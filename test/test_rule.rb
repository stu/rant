
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

# Ensure we run in testproject directory.
$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestRule < Test::Unit::TestCase
    def setup
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
	FileUtils.rm_rf Dir["*.t*"]
    end
if Rant::Env.find_bin("cc") && Rant::Env.find_bin("gcc")
    # Note: we are assuming that "cc" invokes "gcc"!
    def test_cc
	FileUtils.touch "a.t.c"
	capture_std do
	    assert_equal(0, Rant.run("a.t.o", "-frule.rf"))
	end
	assert(test(?f, "a.t.o"))
    end
else
    $stderr.puts "*** cc/gcc not available, less rule tests ***"
    def test_dummy
	assert(true)
    end
end
end
