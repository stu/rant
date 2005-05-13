
require 'test/unit'
require 'tutil'

$testImportCDepDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportCDependencies < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testImportCDepDir
    end
    def teardown
	Dir.chdir $testDir
	FileUtils.rm_rf Dir["*.t"]
    end
    # TODO
    def test_dummy
	assert(true)
    end
end
