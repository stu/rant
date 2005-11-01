
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
    def test_opt_version
        out, err = assert_rant("--version")
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/^rant \d\.\d\.\d$/i, lines.first)
        out2, err2 = assert_rant("-V")
        assert_equal err, err2
        assert_equal out, out2
    end
    def test_no_such_option
        out, err = assert_rant :fail, "-N"
        assert out.empty?
        lines = err.split(/\n/)
        assert lines.size < 3
        assert_match(/\[ERROR\].*option.*\bN\b/, lines.first)
    end
    def test_no_such_long_option
        out, err = assert_rant :fail, "--nix"
        assert out.empty?
        lines = err.split(/\n/)
        assert lines.size < 3
        assert_match(/\[ERROR\].*option.*\bnix\b/, lines.first)
    end
    def test_opt_rantfile_no_such_file
        out, err = assert_rant :fail, "-fdoesnt_exist.rf"
        assert out.empty?
        assert err =~ /\bdoesnt_exist\.rf\b/
    end
end
