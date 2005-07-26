
require 'test/unit'
require 'tutil'


$testImportSignedFileDir ||= File.expand_path(File.dirname(__FILE__))

class TestSignedFile < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportSignedFileDir)
    end
    def teardown
	Dir.chdir($testImportSignedFileDir)
        #FileUtils.rm_rf Dir["*.t"]
        FileUtils.rm_f ".rant.meta" # TODO: enhance AutoClean
        FileUtils.rm_f "sub1/.rant.meta" # TODO: enhance AutoClean
        assert_rant("autoclean")
        assert(Dir["*.t"].empty?)
        assert(Dir["sub1/*.t"].empty?)
        assert(!test(?e, ".rant.meta"))
        assert(!test(?e, "sub1/.rant.meta"))
    end
    def write(fn, str)
        open fn, "w" do |f|
            f.write str
        end
    end
    def test_no_pre_no_action
        assert_rant
        assert(!test(?f, "f1.t"))
        assert_rant
        assert(!test(?f, "f1.t"))
    end
    def test_no_pre
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert_match(/writing/, out)
        assert(test(?f, "f2.t"))
        assert_equal("1\n", File.read("f2.t"))
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert(out.empty?)
        write("f2.t", "2\n")
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert_match(/writing/, out)
        assert_equal("1\n", File.read("f2.t"))
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert(out.empty?)
    end
    def test_one_pre
        out, err = assert_rant("f3.t")
        assert(test(?f, "f2.t"))
        assert(test(?f, "f3.t"))
        assert_equal("1\n", File.read("f2.t"))
        assert_equal("1\n", File.read("f3.t"))
        assert_match(/writing f2\.t\nwriting f3\.t/, out)
        assert(err.empty?)
        FileUtils.rm "f2.t"
        out, err = assert_rant("f3.t")
        assert(test(?f, "f2.t"))
        assert(test(?f, "f3.t"))
        assert_equal("1\n", File.read("f2.t"))
        assert_equal("1\n", File.read("f3.t"))
        assert_match(/\Awriting f2\.t\n\Z/, out)
        assert(!out.include?("f3")) # OK, redundant
        FileUtils.rm "f2.t"
        assert_rant("f2.t", "content=2")
        assert(test(?f, "f2.t"))
        assert_equal("2", File.read("f2.t"))
        out, err = assert_rant("f3.t")
        assert_equal("2", File.read("f2.t"))
        assert_equal("1\n", File.read("f3.t"))
        assert(err.empty?)
        assert_match(/\Awriting f3\.t\n\Z/, out)
        assert(!out.include?("f2")) # OK, redundant
        out, err = assert_rant("f3.t")
        assert(out.empty?)
    end
    def test_one_pre_list
        out, err = assert_rant("f4.t")
        assert(test(?f, "f2.t"))
        assert(test(?f, "f3.t"))
        assert(test(?f, "f4.t"))
        assert_equal("1\n", File.read("f2.t"))
        assert_equal("1\n", File.read("f3.t"))
        assert_equal("1\n", File.read("f4.t"))
        assert(err.empty?)
        assert_equal("writing f2.t\nwriting f3.t\nwriting f4.t\n", out)
        out, err = assert_rant("f4.t")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("autoclean")
        assert(!test(?e, "f2.t"))
        assert(!test(?e, "f3.t"))
        assert(!test(?e, "f4.t"))
    end
    def test_opt_tasks
        out, err = assert_rant("--tasks")
        assert(err.empty?)
        lines = out.split(/\n/)
        assert_equal(2, lines.size)
        assert_match(/rant\s+#.*f1\.t/, lines[0])
        assert_match(/rant\s+f3\.t\s+#\s+create f3\.t\b/, lines[1])
        assert(!test(?e, ".rant.meta"))
        assert(Dir["*.t"].empty?)
    end
    def test_file_mtime_with_signed_dep
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert(test(?f, "f2.t"))
        assert(test(?f, "f5.t"))
        assert_equal("1\n", File.read("f2.t"))
        assert_equal("1\n", File.read("f5.t"))
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert(out.empty?)
        timeout
        FileUtils.touch "f2.t"
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert_match(/\Awriting f5\.t\n\Z/, out)
        assert_equal("1\n", File.read("f2.t"))
        assert_equal("1\n", File.read("f5.t"))
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert(out.empty?)
    end
    def test_with_file_mtime_dep
        out, err = assert_rant("f6.t")
        assert(test(?f, "f2.t"))
        assert(test(?f, "f5.t"))
        assert(test(?f, "f6.t"))
        assert_equal("1\n", File.read("f2.t"))
        assert_equal("1\n", File.read("f5.t"))
        assert_equal("1\n", File.read("f6.t"))
        out, err = assert_rant("f6.t")
        assert(err.empty?)
        assert(out.empty?)
=begin
        # could be optimized to work
        timeout
        FileUtils.touch "f2.t"
        out, err = assert_rant("f6.t")
        assert(err.empty?)
        lines = out.split(/\n/)
        p lines
        assert_equal(1, lines.size)
        assert_equal("writing f5.t", lines.first)
=end
    end
    def test_file_dep_signed_dep_file_dep
        out, err = assert_rant(:fail, "f7.t")
        assert(out.empty?)
        lines = err.split(/\n/)
        assert_equal(4, lines.size)
        assert_match(/\[ERROR\].*Rantfile.*29/, lines[0])
        assert_match(/no.*a\.t/, lines[1])
        assert_match(/f7\.t.*fail/, lines[2])
        write("a.t", "a\n")
        out, err = assert_rant(:fail, "f7.t")
        assert_equal("writing f2.t\n", out)
        lines = err.split(/\n/)
        assert_equal(4, lines.size)
        assert_match(/\[ERROR\].*Rantfile.*29/, lines[0])
        assert_match(/no.*b\.t/, lines[1])
        assert_match(/f7\.t.*fail/, lines[2])
        write("b.t", "b\n")
        out, err = assert_rant("f7.t")
        assert(err.empty?)
        lines = out.split(/\n/)
        assert_equal(1, lines.size)
        assert_equal("writing f7.t", lines.first)
        timeout
        FileUtils.touch "b.t"
        out, err = assert_rant("f7.t")
        assert(err.empty?)
        assert(out.empty?)
        write("b.t", "c\n")
        out, err = assert_rant("f7.t")
        assert(err.empty?)
        lines = out.split(/\n/)
        assert_equal(1, lines.size)
        assert_equal("writing f7.t", lines.first)
        out, err = assert_rant("f7.t")
        assert(err.empty?)
        assert(out.empty?)
        out, err = assert_rant("f7.t")
        assert(err.empty?)
        assert(out.empty?)
    ensure
        FileUtils.rm_f %w(a.t b.t)
    end
    def test_dep_on_no_action
        out, err = assert_rant("f8.t")
        assert(err.empty?)
        assert(test(?f, "f8.t"))
        assert(!test(?e, "f1.t"))
        assert_equal("writing f8.t\n", out)
        assert_equal("1\n", File.read("f8.t"))
        out, err = assert_rant("f8.t")
        assert(err.empty?)
        assert(out.empty?)
    end
    def test_dep_on_no_action_fail
        out, err = assert_rant(:fail, "f9.t")
        assert(out.empty?)
        assert_match(/need f1\.t/, err)
        assert_match(/38/, err)
        out, err = assert_rant(:fail, "f9.t")
        assert(out.empty?)
        assert_match(/need f1\.t/, err)
        assert_match(/38/, err)
    end
    def test_action_no_create
        out, err = assert_rant("f10.t")
        assert(err.empty?)
        assert_equal("should create f10.t\n", out)
        out, err = assert_rant("f10.t")
        assert(err.empty?)
        assert_equal("should create f10.t\n", out)
        out, err = assert_rant("f10.t")
        assert(err.empty?)
        assert_equal("should create f10.t\n", out)
    end
    def test_sub1_no_task
        out, err = assert_rant(:fail, "s1.t")
        assert(out.empty?)
        assert_match(/ERROR.*s1\.t/, err)
    end
    def test_sub1
        out, err = assert_rant("sub1/s1.t")
        assert(err.empty?)
        assert(test(?f, "f2.t"))
        assert(test(?f, "sub1/s1.t"))
        out, err = assert_rant("sub1/s1.t")
        assert(err.empty?)
        assert(out.empty?)
        assert_equal("1\n", File.read("f2.t"))
        assert_equal("1\n", File.read("sub1/s1.t"))
    end
end
