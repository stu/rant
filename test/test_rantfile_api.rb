
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestRantfileAPI < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testDir
	@app = Rant::RantApp.new
    end
    def teardown
	Dir.chdir $testDir
        assert_rant("clean")
        assert(!test(?e, "auto.rf"))
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
    def test_name_error_in_task
	open "rf.t", "w" do |f|
	    f << <<-EOF
	    task :a do
		n_i_x
	    end
	    EOF
	end
	out, err = assert_rant(:fail, "-frf.t")
	assert(out.strip.empty?)
	assert_match(/rf\.t/, err)
	assert_match(/2/, err)
	assert_match(/n_i_x/, err)
    end
    def test_make_file
        out, err = assert_rant("make_file")
        assert(err.empty?)
        assert(test(?f, "make_file.t"))
        out, err = assert_rant("make_file")
        assert(out.empty?)
        assert(err.empty?)
    end
    def test_make_files
        out, err = assert_rant("make_files=ON")
        assert(err.empty?)
        assert(test(?f, "make_files.t"))
        assert(test(?f, "make_files_dep.t"))
        out, err = assert_rant("make_files=ON")
        assert(out.empty?)
    end
    def test_dep_on_make_files_fail
        assert_rant(:fail, "dep_on_make_files")
        assert(!test(?e, "make_files.t"))
        assert(!test(?e, "make_files_dep.t"))
    end
    def test_dep_on_make_files
        assert_rant("dep_on_make_files", "make_files=1")
        assert(test(?e, "make_files.t"))
        assert(test(?e, "make_files_dep.t"))
    end
    def test_make_path
        out, err = assert_rant("make_path=1")
        assert(err.empty?)
        assert(test(?d, "basedir.t/a/b"))
        out, err = assert_rant("make_path=1")
        assert(out.empty?)
        assert(err.empty?)
    end
    def test_make_subfile
        out, err = assert_rant("make_gen_with_block=1")
        assert(err.empty?)
        assert(test(?f, "a.t/a.t"))
        out, err = assert_rant("make_gen_with_block=1")
        assert(out.empty?)
        assert(err.empty?)
    end
    def test_source_self
        open "source_self.t", "w" do |f|
            f << <<-EOF
            puts "test"
            task :a
            source "source_self.t"
            EOF
        end
        out, err = nil, nil
        th = Thread.new { out, err = assert_rant("-fsource_self.t") }
        # OK, give it one second to complete
        assert_equal(th, th.join(1))
        assert_equal("test\n", out)
        assert(err.empty?)
    end
end
