
require 'test/unit'
require 'tutil'

$testImportSubFileDir ||= File.expand_path(File.dirname(__FILE__))

class TestSubFile < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportSubFileDir)
    end
    def teardown
	FileUtils.rm_rf Dir["*.t"]
    end
    def test_run_cmd
	assert_rant("sub.t/file")
	assert(test(?d, "sub.t"))
	assert(test(?f, "sub.t/file"))
    end
    def test_desc
	out, err = assert_rant("--tasks")
	assert_match(%r{sub2\.t/file\s*#.*some subfile}, out)
    end
    def test_no_block
	assert_rant("sub2.t/file")
	assert(test(?d, "sub2.t"))
	assert(!test(?e, "sub2.t/file"))
    end
end
