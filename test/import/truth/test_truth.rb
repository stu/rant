
require 'test/unit'
require 'tutil'

$testImportTruthDir ||= File.expand_path(File.dirname(__FILE__))

class TestTruth < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportTruthDir) unless Dir.pwd == $testImportTruthDir
    end
    def test_opt_tasks
	out, err = assert_rant("--tasks")
	assert_match(
	    /print hello.*\n.*touch rm\.t.*\n.*this file is useless/, out)
    end
    def test_drag
	assert_rant("rm.t")
	assert(test(?f, "rm.t"))
	assert_rant("clean")
	assert(!test(?e, "rm.t"))
    end
end
