
require 'test/unit'
require 'rant'

$testPluginConfigureDir = File.expand_path(File.dirname(__FILE__))

class TestPluginConfigure < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	sys.cd($testPluginConfigureDir) unless Dir.pwd == $testPluginConfigureDir
    end
    def teardown
	assert_equal(Rant.run("clean"), 0)
	assert(!File.exist?("hello"),
	    "hello should have been removed by `clean'")
	assert(!File.exist?("config"),
	    "config should have been removed by `clean'")
    end
    def test_startup
	assert_equal(Rant.run([]), 0)
	assert(File.exist?("hello"),
	    "target `hello' is first, and should have been run")
	assert(!File.exist?("config"),
	    "config should have used defaults, no writing")
    end
    def test_configure
	assert_equal(Rant.run("configure"), 0)
	assert(File.exist?("config"),
	    "config should have been created by `configure'")
	assert_equal(Rant.run("value_a_guess"), 0,
	    "value_a_guess should be choosen based on config")
	assert(File.exist?("value_a_guess"))
    end
    def test_configure_immediate
	assert_equal(Rant.run(%w(configure value_a)), 0,
	    "on task creation time, conf['a'] had the value `value_a'")
	assert(!File.exist?("value_a_guess"))
	assert(File.exist?("value_a"))
    end
    def test_defaults
	assert_equal(Rant.run("value_a"), 0)
	assert(File.exist?("value_a"))
	assert(!File.exist?("value_a_guess"))
    end
end
