
require 'test/unit'
require 'tutil'

$testImportMetaDataDir ||= File.expand_path(File.dirname(__FILE__))

class TestMetaData < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportMetaDataDir)
    end
    def teardown
	Dir.chdir($testImportMetaDataDir)
	FileUtils.rm_rf(Dir["*.t"] + %w(.rant.meta sub/.rant.meta sub/b))
    end
    def test_fetch_set_fetch
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("nil\n\"touch a\"\n", out)
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("\"touch a\"\n\"touch a\"\n", out)
    end
    def test_subdir
        out, err = assert_rant("subdir=true", "sub/b")
        assert(err.empty?)
        assert_equal("nil\nnil\ntouch b\n", out)
        assert(test(?f, ".rant.meta"))
        assert(test(?f, "sub/.rant.meta"))
        out, err = assert_rant("subdir=true", "sub/b")
        assert(err.empty?)
        assert_equal("\"touch a\"\n\"create b\"\n", out)
    end
    def test_rant_import
        run_import("-q", "--auto", "make.t")
        assert_exit
        FileUtils.rm ".rant.meta"
        out = run_ruby("make.t", "subdir=true", "sub/b")
        assert_exit
        assert_equal("nil\nnil\ntouch b\n", out)
        assert(test(?f, ".rant.meta"))
        assert(test(?f, "sub/.rant.meta"))
        out = run_ruby("make.t", "subdir=true", "sub/b")
        assert_exit
        assert_equal("\"touch a\"\n\"create b\"\n", out)
    end
    def test_more_commands_and_lines
        FileUtils.mkdir "more.t"
        Dir.chdir "more.t"
        open "Rantfile", "w" do |f|
            f << <<-EOF
            import "metadata"
            task :dummy
            puts var[:__meta_data__].fetch("x", "a")
            puts var[:__meta_data__].fetch("y", "a")
            puts var[:__meta_data__].fetch("x", "b")
            #STDERR.puts(var[:__meta_data__].instance_variable_get(:@store).inspect)
            var[:__meta_data__].set("x", "1\n2\n\n", "a")
            var[:__meta_data__].set("y", "3\n4", "a")
            var[:__meta_data__].set("x", "5", "b")
            #STDERR.puts(var[:__meta_data__].instance_variable_get(:@store).inspect)
            EOF
        end
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("nil\nnil\nnil\n", out)
        assert(test(?f, ".rant.meta"))
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("1\n2\n3\n4\n5\n", out)
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("1\n2\n3\n4\n5\n", out)
    end
    def test_write_current_version
            top_data = <<EOF
Rant
a
1
cmd
1
touch a
EOF
            sub_data = <<EOF
Rant
b
1
cmd
1
create b
EOF
        assert_rant("subdir=true", "sub/b")
        assert_equal(top_data, File.read(".rant.meta"))
        assert_equal(sub_data, File.read("sub/.rant.meta"))
    end
    def test_read_meta_data_format_version_0_4_4
        assert(!test(?e, ".rant.meta"))
        assert(!test(?e, "sub/.rant.meta"))
        open ".rant.meta", "w" do |f|
            f << <<EOF
Rant
a
1
cmd
1
touch a
EOF
        end
        open "sub/.rant.meta", "w" do |f|
            f << <<EOF
Rant
b
1
cmd
1
create b
EOF
        end
        out, err = assert_rant
        assert(err.empty?)
        assert_equal("\"touch a\"\n\"touch a\"\n", out)
        out, err = assert_rant("subdir=true", "sub/b")
        assert(err.empty?)
        assert_equal("\"touch a\"\n\"create b\"\n", out)
    end
end
