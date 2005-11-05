
require 'test/unit'
require 'tutil'

# Ensure we run in testproject directory.
$testDryRunDir ||= File.expand_path(File.dirname(__FILE__))

class TestDryRun < Test::Unit::TestCase
    include Rant::TestUtil
    def setup
	Dir.chdir($testDryRunDir)
    end
    def teardown
    end
    def test_default
        cmd = "#{Rant::Sys.sp Rant::Env::RUBY_EXE} -e \"puts ARGV.join(' ')\" foo.t foo.c > foo.t"
        out, err = assert_rant "-n"
        assert err.empty?
        assert !test(?e, "foo.t")
        assert out !~ /installing foo/
        lines = out.split(/\n/)
        assert_match(/Executing.*\bfoo\.t\b/i, lines[0])
        assert_match(/\s+-\s+SHELL\b/i, lines[1])
        assert_match(/\s+#{Regexp.escape cmd}/, lines[2])
        assert_match(/Executing.*\binstall\b/i, lines[3])
        assert_match(/\s+-\s+Ruby Proc\b.*\bRantfile\b.*\b4\b/i, lines[4])
        out2, err2 = assert_rant "--dry-run"
        assert_equal out, out2
        assert_equal err, err2
    end
end
