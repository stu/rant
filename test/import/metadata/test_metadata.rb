
require 'test/unit'
require 'tutil'

$testImportMetaDataDir ||= File.expand_path(File.dirname(__FILE__))

class TestMetaData < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportMetaDataDir)
    end
    def teardown
	FileUtils.rm_rf(Dir["*.t"] + %w(.rant.meta))
    end
    def test_fetch_set_fetch
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("nil\n\"touch a\"\n", out)
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("\"touch a\"\n\"touch a\"\n", out)
    end
end
