
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestRantInterface < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end
    def test_cmd_targets
	@app = Rant::RantApp.new
	op = capture_stderr {
	    assert_equal(@app.run("-f non_existent", "target", "-aforced_target"), 1,
		"Rant should fail because there is no such Rantfile.")
	}
	assert(op =~ /\[ERROR\]/,
	    "rant should print error message if -f RANTFILE not found")
	assert_equal(@app.cmd_targets.size, 2,
	    "there were to targets given on commandline")
	assert(@app.cmd_targets.include?("target"))
	assert(@app.cmd_targets.include?("forced_target"))
	assert(@app.cmd_targets.first == "forced_target",
	    "forced_target should run first")
    end
    def test_envvar_on_cmdline
	@app = Rant::RantApp.new
	@app.context.var.env "VAR"
	assert_equal(@app.run("VAR=VAL"), 0)
	assert_equal(ENV["VAR"], "VAL",
	    "rant should set arguments of form VAR=VAL in var")
    end
    def test_envvar_on_cmdline_lc
	@app = Rant::RantApp.new
	assert_equal(@app.run("var2=val2"), 0)
	assert_equal(@app.context.var["var2"], "val2",
	    "rant should set arguments of form var2=val2 in var")
    end
    def test_opt_targets
	@app = Rant::RantApp.new
	@app.desc 'This is a "public" target.'
	@app.task :public_task
	@app.task :private_task
	op = capture_stdout { 
	    assert_equal(@app.run("--tasks"), 0)
	}
	assert(op =~ /\bpublic_task\b/,
	    "rant -T output should contain name of described task")
	assert(op !~ /private_task/,
	    "rant -T output shouldn't contain name of not-described task")
    end
    def test_opt_help
	op = capture_stdout {
	    assert_equal(Rant.run("--help"), 0,
		"rant --help should return 0")
	}
	assert(!op.empty?,
	    "rant --help should write to STDOUT")
	assert(op.split("\n").size > 15,
	    "rant --help should print at least 16 lines to STDOUT")
    end
end
