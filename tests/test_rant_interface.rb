
require 'test/unit'
require 'rant'

$testDir = File.expand_path(File.dirname(__FILE__))

class TestRantInterface < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	cd($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end
    def test_cmd_targets
	@app = RantApp.new("-f non_existent", "target", "-aforced_target")
	assert_equal(@app.run, 1,
	    "Rant should fail because there is no such Rantfile.")
	assert_equal(@app.cmd_targets.size, 2,
	    "there were to targets given on commandline")
	assert(@app.cmd_targets.include?("target"))
	assert(@app.cmd_targets.include?("forced_target"))
	assert(@app.cmd_targets.first == "forced_target",
	    "forced_target should run first")
    end
    def test_envvar_on_cmdline
	@app = RantApp.new("VAR=VAL")
	assert_equal(@app.run, 0)
	assert_equal(ENV["VAR"], "VAL",
	    "rant should set arguments of form VAR=VAL in ENV")
    end
    def test_envvar_on_cmdline_lc
	@app = RantApp.new("var2=val2")
	assert_equal(@app.run, 0)
	assert_equal(ENV["var2"], "val2",
	    "rant should set arguments of form var2=val2 in ENV")
    end
end
