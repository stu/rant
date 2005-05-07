
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestRantfileAPI < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
	@app = Rant::RantApp.new
    end
    def teardown
	FileUtils.rm_rf Dir["*.t"]
    end
    def test_action
	@app.args << "act_verbose=1"
	out, err = capture_std do
	    assert_equal(0, @app.run)
	end
	assert_match(/running action/, out)
    end
    def test_action_query
	@app.args << "act_verbose=1" << "--tasks"
	out, err = capture_std do
	    assert_equal(0, @app.run)
	end
	assert(out !~ /running action/)
    end
    def test_rac_build
	capture_std do
	    assert_equal(0, @app.run)
	end
	assert(test(?f, "version.t"))
	old_mtime = File.mtime "version.t"
	timeout
	capture_std do
	    assert_equal(0, Rant::RantApp.new.run)
	end
	assert_equal(old_mtime, File.mtime("version.t"))
    end
    def test_rac_build_cd
	assert_rant("tmp.t/Rantfile", "subdir_tmp", "build_test_t")
    end
    def test_string_sub_ext
	assert_equal("hello.txt", "hello.sxw".sub_ext(".sxw", ".txt"))
    end
    def test_string_sub_ext_2
	assert_equal("hello.txt", "hello.sxw".sub_ext("sxw", "txt"))
    end
    def test_string_sub_ext_one_arg
	assert_equal("hello.txt", "hello.sxw".sub_ext("txt"))
    end
    def test_string_sub_ext_new_ext
	assert_equal("hello.txt", "hello".sub_ext("txt"))
    end
    def test_string_sub_ext_dot
	assert_equal("hello.txt", "hello.".sub_ext("txt"))
    end
    def test_string_sub_ext_empty_str
	assert_equal("hello.", "hello.txt".sub_ext(""))
    end
    def test_string_sub_ext_nil
	assert_equal("hello.", "hello.txt".sub_ext(nil))
    end
end
