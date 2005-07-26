
require 'test/unit'
require 'tutil'

$testImportNodesSignedDir ||= File.expand_path(File.dirname(__FILE__))

class TestNodesSigned < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportNodesSignedDir)
    end
    def teardown
	Dir.chdir($testImportNodesSignedDir)
        assert_rant("autoclean")
        assert(Dir["*.t"].empty?)
        assert(!test(?e, ".rant.meta"))
    end
    def write(fn, str)
        open fn, "w" do |f|
            f.write str
        end
    end
    def test_file
        out, err = assert_rant("f1.t")
        assert(err.empty?)
        assert_equal("writing f1.t\n", out)
        assert(test(?f, "f1.t"))
        assert_equal("1\n", File.read("f1.t"))
        out, err = assert_rant
        assert(out.empty?)
        assert(err.empty?)
        assert(!test(?e, "a"))
        write("f1.t", "2\n")
        out, err = assert_rant
        assert_equal("writing f1.t\n", out)
        assert(test(?f, "f1.t"))
        assert_equal("1\n", File.read("f1.t"))
        out, err = assert_rant
        assert(out.empty?)
        assert(err.empty?)
    end
    def test_directory
        out, err = assert_rant("d1.t")
        assert(test(?d, "d1.t"))
        out, err = assert_rant("d1.t")
        assert(err.empty?)
        assert(out.empty?)
    end
    def test_directory_with_pre_and_block
        write("a.t", "a\n")
        out, err = assert_rant(:fail, "base.t/s/s")
        assert(!test(?e, "base.t"))
        assert_match(/Rantfile[^\n]+14/, err)
        assert_match(/base\.t/, err)
        FileUtils.mkdir "base.t"
        out, err = assert_rant("base.t/s/s")
        assert(test(?f, "base.t/s/s/t"))
        assert_equal("a\n1\n", File.read("base.t/s/s/t"))
        out, err = assert_rant("base.t/s/s")
        assert(out.empty?)
        assert(err.empty?)
        assert_rant("-af1.t", "content=2")
        assert_equal("2", File.read("f1.t"))
        out, err = assert_rant("base.t/s/s")
        assert(test(?f, "base.t/s/s/t"))
        assert_equal("a\n2", File.read("base.t/s/s/t"))
        assert(!out.include?("f1.t"))
        assert(out.include?("copying"))
        out, err = assert_rant("base.t/s/s")
        assert(out.empty?)
        assert(err.empty?)
    ensure
        FileUtils.rm_f "a.t"
        FileUtils.rm_rf "base.t"
    end
    def test_subfile
        out, err = assert_rant("d2.t/f", "subfile=1")
        assert(err.empty?)
        assert(test(?f, "f1.t"))
        assert(test(?f, "d2.t/f"))
        assert_equal("1\n", File.read("f1.t"))
        assert_equal("1\n", File.read("d2.t/f"))
        out, err = assert_rant("d2.t/f", "subfile=1")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("subfile=1", "autoclean")
    end
    def test_file_with_dep_on_dir_with_pre_and_block
        FileUtils.mkdir "base.t"
        write("a.t", "a\n")
        out, err = assert_rant("f2.t")
        assert(test(?f, "base.t/s/s/t"))
        assert(test(?f, "f2.t"))
        assert_equal(File.read("base.t/s/s/t"), File.read("f2.t"))
        assert(err.empty?)
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert(out.empty?)
        FileUtils.rm "f2.t"
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert_equal("cp base.t/s/s/t f2.t\n", out)
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert(out.empty?)
        write("a.t", "aa\n")
        out, err = assert_rant("f2.t")
        assert_equal(File.read("base.t/s/s/t"), File.read("f2.t"))
        assert(err.empty?)
        assert_match(/\bcp\b/, out)
        out, err = assert_rant("f2.t")
        assert(err.empty?)
        assert(out.empty?)
    ensure
        FileUtils.rm_f "a.t"
        FileUtils.rm_rf "base.t"
    end
end
