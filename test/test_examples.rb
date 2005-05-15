
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

$examplesDir ||= File.expand_path(
    File.join(File.dirname(File.dirname(__FILE__)), "doc", "examples"))

$cc_is_gcc ||= Rant::Env.find_bin("cc") && Rant::Env.find_bin("gcc")
class TestExamples < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $examplesDir
    end
    def test_myprog
	Dir.chdir "myprog"
	assert_match(/Build myprog.*\n.*Remove compiler products/,
	    run_rant("--tasks"))
	assert(!test(?f, "myprog"))
	if $cc_is_gcc
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
    def test_directedrule
	Dir.chdir "directedrule"
	assert_match(/Build foo/, run_rant("-T"))
	assert(!test(?f, "foo"))
	if $cc_is_gcc
	    run_rant
	    assert(test(?f, "foo"))
	end
	run_rant("clean")
	Dir["**/*.o"].each { |f| assert(!test(?e, f)) }
    end
    def test_c_dependencies
	Dir.chdir "c_dependencies"
	assert_match( /\bhello\b.*\n.*\bclean\b.*\n.*\bdistclean\b/,
	    run_rant("-T"))
	assert(!test(?f, "hello"))
	if $cc_is_gcc
	    run_rant
	    assert(test(?f, "hello"))
	else
	    run_rant("c_dependencies")
	end
	run_rant("clean")
	assert(Dir["**/*.o"].empty?)
	assert(!test(?f, "hello"))
	assert(test(?f, "c_dependencies"))
	if $cc_is_gcc
	    run_rant
	    assert(test(?f, "hello"))
	end
	run_rant("distclean")
	assert(Dir["**/*.o"].empty?)
	assert(!test(?f, "c_dependencies"))
	assert(!test(?f, "hello"))
    end
end
