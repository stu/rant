
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestFileUtils < Test::Unit::TestCase
    include Rant::Sys

    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end

    def test_ruby
	op = capture_stdout do
	    ruby('-e ""') { |succ, stat|
		assert(succ)
		assert_equal(stat, 0)
	    }
	end
	assert(op =~ /\-e/i,
	    "Sys should print command with arguments to $stdout")
    end
    def test_split_path
	pl = split_path("/home/stefan")
	assert_equal(pl.size, 3,
	    "/home/stefan should get split into 3 parts")
	assert_equal(pl[0], "/")
	assert_equal(pl[1], "home")
	assert_equal(pl[2], "stefan")
	pl = split_path("../")
	assert_equal(pl.size, 1,
	    '../ should be "split" into one element')
	assert_equal(pl[0], "..")
    end
    # perhaps this test should go into a seperate file
    def test_toplevel
	assert_match(/\btd\b/, run_rant("-ftoplevel.rf"),
	    "Sys module should print commands to stdout")
	assert_equal(0, $?,
	    "rant -ftoplevel.rf in test/ should be successfull")
    ensure
	File.delete "td" if File.exist? "td"
    end
    # ...ditto
    def test_name_error
	File.open("name_error.rf", "w") { |f|
	    f << "no_var_no_method\n"
	}
	out, err = capture_std do
	    assert_equal(1, Rant.run("-fname_error.rf"))
	end
	assert_match(/Name\s*Error/i, err.split("\n").first)
    ensure
	File.delete "name_error.rf" if File.exist? "name_error.rf"
    end
    # ...
    def test_standalone
	out = `#{Rant::Env::RUBY} standalone.rf`
	assert(0, $?)
	assert_match(/^t_standalone/, out)
    end
end
