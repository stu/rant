
require 'test/unit'
require 'rant'

class TestRantInterface < Test::Unit::TestCase
    def setup
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
end
