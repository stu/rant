
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

#$examplesDir ||= File.expand_path(
#    File.join(File.dirname(File.dirname(__FILE__)), "doc", "examples"))
$examplesDir ||= File.join(
    File.dirname(File.dirname(File.expand_path(__FILE__))),
    "doc", "examples")

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
    def test_c_cpp_examples
        Dir.chdir "c_cpp_examples"
        proj_pwd = Dir.pwd
        out, err = assert_rant("--tasks")
        # TODO: replace with a not-so-strict regex
op = <<EOF
rant run                      # Run all C and C++ tests.
rant build                    # Build all.
rant autoclean                # Remove all autogenerated files.
rant pkg/c_cpp_exercises.tgz  # Create source package.
EOF
        assert_equal(op, out)
        assert(err.empty?)
        gen_files = %w(
            c/problem_1_1/Rantfile
            c++/problem_1_1/Rantfile
            c/problem_1_1/c_dependencies
            c++/problem_1_1/c_dependencies
            c/problem_1_1/test
            c++/problem_1_1/test
            c/problem_1_1/main.o
            c++/problem_1_1/main.o
            c/problem_1_1/test.o
            c++/problem_1_1/test.o
            c/problem_1_1/another_test.o
            c++/problem_1_1/another_test.o
            pkg
        )
        if Rant::Env.find_bin("gcc") && Rant::Env.find_bin("g++")
            out = run_rant
            assert_exit
            assert_equal(2, out.scan(/Hello\, world\!/).size)
            out, err = assert_rant("build")
            assert(out.empty?)
            assert(err.empty?)
        else
            STDERR.puts "*** gcc and/or g++ not available, less example testing ***"
        end
        assert_rant("pkg/c_cpp_exercises.tgz")
        # TODO: check archive contents
        assert(test(?f, "pkg/c_cpp_exercises.tgz"))
        out, err = assert_rant("pkg/c_cpp_exercises.tgz")
        assert(out.empty?)
        assert(err.empty?)
        assert_rant("autoclean")
        gen_files.each { |f|
            assert(!test(?e, f),
                "#{f} should have been removed by autoclean")
        }
        if Rant::Env.find_bin("gcc")
            FileUtils.cp "c/template.rf", "c/problem_1_1/Rantfile"
            Dir.chdir "c/problem_1_1"
            out = run_rant
            assert(out.include?("Hello, world!"))
            assert_rant("autoclean")
            FileUtils.rm_f "Rantfile"
            Dir.chdir proj_pwd
            gen_files.each { |f|
                assert(!test(?e, f),
                    "#{f} should have been removed by autoclean")
            }
        end
    ensure
        Dir.chdir proj_pwd
        FileUtils.rm_f "c/problem_1_1/Rantfile"
        FileUtils.rm_f "c++/problem_1_1/Rantfile"
    end
end
