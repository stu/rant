
require 'test/unit'
require 'wgrep'
require 'fileutils'

class TestWGrep < Test::Unit::TestCase
    def test_run
	stdout = $stdout
	output = File.new "wgrep_out", "w"
	$stdout = output
	assert_equal(WGrep::WGrep.new.run(%w(Hello text)), 0,
		"Input to wgrep is ok, so `run' should return 0.")
	output.close
	$stdout = stdout
	lines = File.read("wgrep_out").split("\n")
	assert_equal(lines.size, 1)
    ensure
	FileUtils.rm_f "wgrep_out"
	$stdout = stdout
    end
end
