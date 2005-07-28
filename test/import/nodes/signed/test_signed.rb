
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
    def test_source_node_single_fail
        out, err = assert_rant(:fail, "f3.t")
        assert(out.empty?)
        assert(!test(?e, "f3.t"))
        assert(!test(?e, "c1.t"))
        assert(!test(?e, ".rant.meta"))
        lines = err.split(/\n/)
        assert(lines.size < 5)
        assert_match(/ERROR.*Rantfile.*34/, lines[0])
        assert_match(/SourceNode.*c1\.t/, lines[1])
        assert_match(/Task.*f3\.t.*fail/, lines[2])
    end
    def test_source_node_single
        write("c1.t", "c\n")
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert(test(?f, "f3.t"))
        assert_equal("c\n", File.read("f3.t"))
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert(out.empty?)
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("autoclean")
        assert(!test(?e, "f3.t"))
        assert(test(?f, "c1.t"))
        assert_equal("c\n", File.read("c1.t"))
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert(test(?f, "f3.t"))
        assert_equal("c\n", File.read("f3.t"))
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert(out.empty?)
        write("c1.t", "c1\n")
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert_equal("writing f3.t\n", out)
        assert_equal("c1\n", File.read("f3.t"))
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert(out.empty?)
    ensure
        FileUtils.rm_f "c1.t"
    end
    def test_source_node_fail
        write("c1.t", "c\n")
        write("c2.t", "c\n")
        out, err = assert_rant(:fail, "f4.t")
        assert(test(?f, "f3.t"))
        assert_equal("writing f3.t\n", out)
        lines = err.split(/\n/)
        assert(lines.size < 5)
        assert_match(/ERROR.*Rantfile.*36/, lines[0])
        assert_match(/SourceNode.*c3\.t/, lines[1])
        assert_match(/Task.*f4\.t.*fail/, lines[2])
        out, err = assert_rant("f3.t")
        assert(err.empty?)
        assert(out.empty?)
    ensure
        FileUtils.rm_f "c1.t"
        FileUtils.rm_f "c2.t"
    end
    def test_source_node
        write("c1.t", "c\n")
        write("c2.t", "c\n")
        write("c3.t", "c\n")
        out, err = assert_rant("f4.t")
        assert(err.empty?)
        assert(!out.empty?)
        assert(test(?f, "f3.t"))
        assert(test(?f, "f4.t"))
        assert_equal("c\nc\n", File.read("f4.t"))
        out, err = assert_rant("f4.t")
        assert(err.empty?)
        assert(out.empty?)
        write("c3.t", "c3\n")
        out, err = assert_rant("f4.t")
        assert(err.empty?)
        assert_equal("writing f4.t\n", out)
        assert_equal("c\nc\n", File.read("f4.t"))
        out, err = assert_rant("f4.t")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("autoclean")
        assert(test(?f, "c1.t"))
        assert(test(?f, "c2.t"))
        assert(test(?f, "c3.t"))
        assert(!test(?e, "f3.t"))
        assert(!test(?e, "f4.t"))
    ensure
        FileUtils.rm_f "c1.t"
        FileUtils.rm_f "c2.t"
        FileUtils.rm_f "c3.t"
    end
    def test_2source_node
        write("c1.t", "c\n")
        write("c2.t", "c\n")
        write("c3.t", "c\n")
        write("c4.t", "c\n")
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert(test(?f, "f5.t"))
        assert_match(/cp.*c2\.t.*f5\.t/, out)
        assert_equal("c\n", File.read("f5.t"))
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert(out.empty?)
        write("c3.t", "c3\n")
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert_match(/cp.*c2\.t.*f5\.t/, out)
        assert_equal("c\n", File.read("f5.t"))
        out, err = assert_rant("f5.t")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("autoclean")
        assert(test(?f, "c1.t"))
        assert(test(?f, "c2.t"))
        assert(test(?f, "c3.t"))
        assert(test(?f, "c4.t"))
        assert(!test(?e, "f5.t"))
    ensure
        FileUtils.rm_f "c1.t"
        FileUtils.rm_f "c2.t"
        FileUtils.rm_f "c3.t"
        FileUtils.rm_f "c4.t"
    end
    def test_source_node_in_subdir
        write("sub1/c1.t", "c\n")
        write("sub1/c2.t", "c\n")
        write("c5.t", "c\n")
        write("c6.t", "c\n")
        out, err = assert_rant("f6.t")
        assert(err.empty?)
        assert_equal("writing f6.t\n", out)
        assert(test(?f, "f6.t"))
        assert_equal("1\n", File.read("f6.t"))
        out, err = assert_rant("f6.t")
        assert(err.empty?)
        assert(out.empty?)
        write("sub1/c2.t", "c2\n")
        out, err = assert_rant("f6.t")
        assert(err.empty?)
        assert_equal("writing f6.t\n", out)
        assert_equal("1\n", File.read("f6.t"))
        out, err = assert_rant("f6.t")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("autoclean")
        assert(test(?f, "sub1/c1.t"))
        assert(test(?f, "sub1/c2.t"))
        assert(test(?f, "c5.t"))
        assert(test(?f, "c6.t"))
        assert(!test(?e, "f6.t"))
    ensure
        FileUtils.rm_f "sub1/c1.t"
        FileUtils.rm_f "sub1/c2.t"
        FileUtils.rm_f "c5.t"
        FileUtils.rm_f "c6.t"
    end
end
