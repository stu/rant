
require 'test/unit'
require 'tutil'

$testImportSignedDirectoryDir ||= File.expand_path(File.dirname(__FILE__))

class TestSignedDirectory < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportSignedDirectoryDir)
    end
    def teardown
	Dir.chdir($testImportSignedDirectoryDir)
        #FileUtils.rm_rf Dir["*.t"]
        FileUtils.rm_f ".rant.meta" # TODO: enhance AutoClean
        assert_rant("autoclean")
        assert(Dir["*.t"].empty?)
        assert(!test(?e, ".rant.meta"))
    end
    def write(fn, str)
        open fn, "w" do |f|
            f.write str
        end
    end
    def test_plain_dir
        out, err = assert_rant
        assert(err.empty?)
        assert(!out.include?("touch"))
        assert(test(?d, "d1.t"))
        out, err = assert_rant
        assert(err.empty?)
        assert(out.empty?)
    end
    def test_with_block
        out, err = assert_rant("d2.t")
        assert(test(?d, "d2.t"))
        assert(test(?f, "d2.t/a"))
        assert(err.empty?)
        out, err = assert_rant("d2.t")
        assert(err.empty?)
        assert(out.empty?)
        out, err = assert_rant("d2.t")
        assert(err.empty?)
        assert(out.empty?)
    end
    def test_block_and_plain_file_deps
        write("a.t", "a\n")
        out, err = assert_rant("d3.t")
        assert(test(?f, "d3.t/a.t"))
        assert_equal("a\n", File.read("d3.t/a.t"))
        assert(err.empty?)
        out, err = assert_rant("d3.t")
        assert(err.empty?)
        assert(out.empty?)
        write("b.t", "b\n")
        out, err = assert_rant("d3.t")
        assert(test(?f, "d3.t/a.t"))
        assert(test(?f, "d3.t/b.t"))
        assert_equal("a\n", File.read("d3.t/a.t"))
        assert_equal("b\n", File.read("d3.t/b.t"))
        assert(err.empty?)
        out, err = assert_rant("d3.t")
        assert(err.empty?)
        assert(out.empty?)
        write("b.t", "bb\n")
        out, err = assert_rant("d3.t")
        assert(test(?f, "d3.t/a.t"))
        assert(test(?f, "d3.t/b.t"))
        assert_equal("a\n", File.read("d3.t/a.t"))
        assert_equal("bb\n", File.read("d3.t/b.t"))
        assert(err.empty?)
        out, err = assert_rant("d3.t")
        assert(err.empty?)
        assert(out.empty?)
        FileUtils.rm "a.t"
        out, err = assert_rant("d3.t")
        assert(test(?f, "d3.t/b.t"))
        assert_equal("bb\n", File.read("d3.t/b.t"))
        assert(err.empty?)
        out, err = assert_rant("d3.t")
        assert(err.empty?)
        assert(out.empty?)
    ensure
        FileUtils.rm_f Dir["{a,b,c}.t"]
    end
end
