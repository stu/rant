
require 'test/unit'
require 'rant/rantlib'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestRantEnv < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end
    def test_on_windows
	# rather primitive test, but should catch obvious programming
	# errors when making changes in when in hurry ;)
	if Rant::Env.on_windows?
	    assert(File::ALT_SEPARATOR,
		"Env says we're on windows, but there is no ALT_SEPARATOR")
	end
    end
    def test_find_bin
	assert(Rant::Env.find_bin(Rant::Env::RUBY),
	    "RUBY_INSTALL_NAME should be found by Env.find_bin, " +
	    "doesn't need to be a bug of Rant")
	# let's check for the `echo' command which should be on most
	# systems:
	have_echo = false
	begin
	    have_echo = `echo hello` =~ /hello/
	rescue Exception
	end
	if have_echo
=begin
            # seems to be not so on windows...
	    echo_bin = Rant::Env.find_bin("echo")
	    assert(echo_bin,
		"echo can be invoked, so find_bin should find it")
	    assert(echo_bin =~ /echo/i)
	    assert(`#{echo_bin} hello` =~ /hello/,
		"echo should be invokable through `#{echo_bin}'")
=end
	else
	    puts "*** echo not available, will not search with find_bin ***"
	end
    end
end
