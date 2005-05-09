
require 'test/unit'
require 'tutil'

# We require 'rant/rantlib' instead of 'rant',
# which would cause the rant.rb (which is ment as a Rantfile)
# to be loaded!
require 'rant/rantlib'

# Ensure we run in testproject directory.
$testProject2Dir = File.expand_path(File.dirname(__FILE__))

class TestProject2 < Test::Unit::TestCase
    include Rant
    include ::Rant::Sys

    def app *args
	@app = ::Rant::RantApp.new(*args)
    end
    def setup
	Dir.chdir($testProject2Dir) unless Dir.pwd == $testProject2Dir
    end
    def teardown
	capture_std do
	    assert_equal(app(%w(-f rantfile.rb -f buildfile clean sub1/clean)).run, 0)
	end
	assert(Dir["r_f*"].empty?,
	    "r_f* files should have been removed by `clean'")
	assert(Dir["b_f*"].empty?,
	    "b_f* files should have been removed by `clean'")
	assert(Dir["sub1/s*f*"].empty?,
	    "sub1/s*f* files should have been removed by `clean'")
    end
    def test_use_first_task
	capture_std do
	    assert_equal(app.run, 0,
		"run method of RantApp should return 0 on success")
	end
	assert(File.exist?("r_f1"))
    end
    def test_deps
	capture_std do
	    assert_equal(app("r_f4").run, 0)
	end
	assert(File.exist?("r_f4"))
	assert(File.exist?("r_f2"))
	assert(File.exist?("r_f1"))
	assert(!File.exist?("r_f3"))
    end
    def test_load_rantfile
	capture_std do
	    app("b_f2")
	    @app.rootdir = $testProject2Dir
	    assert_equal(:return_val, @app.source("buildfile"),
		"source should return value of last expression in Rantfile")
	    assert_equal(@app.run, 0)
	end
	assert(File.exist?("b_f2"))
    end
    def test_subdirs
	capture_std do
	    assert_equal(0, app(%w(-f buildfile sub1/create_s1f1)).run)
	end
	assert(File.exist?("sub1/s1f1"))
    end
    def test_opt_directory
	app %w(insub1_s1f1 -C sub1)
	capture_std do
	    assert_equal(@app.run, 0)
	end
	assert(Dir.pwd !~ /sub1$/,
	    "rant should cd to original dir before returning from `run'")
	assert(test(?f, "sub1/s1f1"),
	    "rant should cd to sub1 and run task insub1_s1f1")
    end
    def test_opth_directory
	app %w(insub1_s1f1)
	#Rant[:directory] = "sub1"
	@app[:verbose] = 2
	@app[:directory] = "sub1"
	capture_std do
	    assert_equal(@app.run, 0)
	end
	assert(Dir.pwd !~ /sub1$/,
	    "rant should cd to original dir before returning from `run'")
	assert(test(?f, "sub1/s1f1"),
	    "rant should cd to sub1 and run task insub1_s1f1")
    end
end
