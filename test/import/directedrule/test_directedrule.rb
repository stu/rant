
require 'test/unit'
require 'tutil'

$testImportDrDir ||= File.expand_path(File.dirname(__FILE__))

class TestDirectedRule < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportDrDir) unless Dir.pwd == $testImportDrDir
    end
    def teardown
	assert_rant("autoclean")
	assert_equal(0, Dir["**/*.t"].size)
    end
    def rant(*args)
	Rant::RantApp.new(*args).run
    end
    def test_cmd_target
	assert_rant
	assert_rant("build.t/3.a")
	assert(test(?d, "build.t"))
	assert(test(?f, "build.t/3.a"))
	assert(!test(?e, "build.t/1.a"))
    end
    def test_dependencies
	assert_rant
	assert_rant("foo.t")
	assert(test(?f, "foo.t"))
    end
end
