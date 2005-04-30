
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

$examplesDir ||= File.expand_path(
    File.join(File.dirname(File.dirname(__FILE__)), "doc", "examples"))

class TestExamples < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($examplesDir) unless Dir.pwd == $examplesDir
    end
    def teardown
    end
    def test_myprog
	Dir.chdir "myprog"
	assert_match(/Build myprog.*\n.*Remove compiler products/,
	    run_rant("--tasks"))
	assert(!test(?f, "myprog"))
	if Rant::Env.find_bin("cc") && Rant::Env.find_bin("gcc")
	    # Warning: we're assuming cc is actually gcc
	    run_rant
	    assert(test(?f, "myprog"))
	else
	    $stderr.puts "*** cc isn't gcc, less example testing ***"
	    # less myprog testing
	end
	run_rant("clean")
	assert(!test(?e, "myprog"))
	assert(!test(?e, "src/myprog"))
	assert(!test(?e, "src/lib.o"))
	assert(!test(?e, "src/main.o"))
    end
end
