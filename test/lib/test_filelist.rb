
require 'test/unit'
require 'tutil'
require 'rant/filelist'
require 'rant/import/sys/more'

$test_lib_dir ||= File.expand_path(File.dirname(__FILE__))

class TestRantFileList < Test::Unit::TestCase
    include Rant::TestUtil
    def assert_entries(entry_ary, fl)
        assert_equal entry_ary.size, fl.size
        entry_ary.each { |entry| assert fl.include?(entry) }
    end
    def setup
	# Ensure we run in test directory.
	Dir.chdir($test_lib_dir)
    end
    def test_require
        in_local_temp_dir do
            Rant::Sys.write_to_file "fl.rb", <<-EOF
                require 'rant/filelist'
                File.open("out", "w") do |f|
                    f.puts Rant::FileList["*.{rb,t}"].sort!
                end
            EOF
            Rant::Sys.touch "a.t"
            Rant::Sys.ruby "-I", ENV["RANT_DEV_LIB_DIR"], "fl.rb"
            assert_equal "a.t\nfl.rb\n", File.read("out")
        end
    end
    def test_create_new
        fl = Rant::FileList.new
        assert_equal [], fl.entries
        in_local_temp_dir do
            Rant::Sys.touch ["a.t", ".a.t"]
            fl.include "*.t"
            assert_entries(["a.t", ".a.t"], fl)
        end
    end
    def test_create_new_with_ary
        ary = ["foo", "bar"]
        fl = Rant::FileList.new(ary)
        assert_equal ["foo", "bar"], fl.entries
    end
    def test_create_bracket_op
        in_local_temp_dir do
            Rant::Sys.touch ["a.t", ".a.t"]
            fl = Rant::FileList["*.t"]
            assert_entries(["a.t"], fl)
        end
    end
    def test_create_glob
        in_local_temp_dir do
            Rant::Sys.touch ["a.t", ".a.t"]
            fl = Rant::FileList.glob("*.t")
            assert_entries(["a.t"], fl)
            fl = Rant::FileList.glob(".*.t")
            # note: no "." and ".." entries
            assert_entries([".a.t"], fl)
            fl = Rant::FileList.glob("*.t") do |fl|
                fl.glob ".*.t"
            end
            assert_equal ["a.t", ".a.t"], fl.entries
        end
    end
    def test_create_glob_all
        in_local_temp_dir do
            Rant::Sys.touch ["a.t", ".a.t"]
            fl = Rant::FileList.glob_all("*.t")
            assert_entries(["a.t", ".a.t"], fl)
            fl = Rant::FileList.glob_all(".*.t")
            # note: no "." and ".." entries
            assert_entries([".a.t"], fl)
            fl = Rant::FileList.glob_all("*.t") do |fl|
                fl.keep(".")
            end
            assert_entries ["a.t", ".a.t", "."], fl
        end
    end
    def test_conversion_from_filelist
        fl1 = Rant::FileList.new
        fl2 = Rant::FileList(fl1)
        assert fl1.equal?(fl2)  # same object
    end
    def test_conversion_from_ary
        fl = Rant::FileList(["foo", "bar"])
        assert fl.kind_of?(Rant::FileList)
        assert_equal ["foo", "bar"], fl.entries
    end
    def test_conversion_from_to_ary
        obj = Object.new
        def obj.to_ary
            ["foo", "bar"]
        end
        fl = Rant::FileList(obj)
        assert fl.kind_of?(Rant::FileList)
        assert_equal ["foo", "bar"], fl.entries
    end
    def test_conversion_from_to_rant_filelist
        obj = Object.new
        def obj.to_rant_filelist
            Rant::FileList.new ["foo", "bar"]
        end
        fl = Rant::FileList(obj)
        assert fl.kind_of?(Rant::FileList)
        assert_equal ["foo", "bar"], fl.entries
    end
    # note: this behaviour might change
    def test_conversion_type_error_string
        assert_raise_kind_of(TypeError) do
            fl = Rant::FileList("some_string")
        end
    end
    def test_conversion_type_error
        assert_raise_kind_of(TypeError) do
            fl = Rant::FileList(Object.new)
        end
    end
    def test_each
        in_local_temp_dir do
            Rant::Sys.touch ["a.t", "b.t", "c.t"]
            ary = []
            Rant::FileList["*.t"].each { |fn|
                ary << fn
            }
            assert_entries ["a.t", "b.t", "c.t"], ary
        end
    end
    def test_enumerable_find
        fl = Rant::FileList.new ["bb", "aa", "c", "d", "a"]
        assert_equal "aa", fl.find { |fn| fn =~ /a/ }
    end
    def test_glob
        in_local_temp_dir do
            all = ["a.t", "b.t", "c.t", ".a.t"]
            Rant::Sys.touch all
            fl = Rant::FileList.new
            fl.include "*.t"
            assert_entries all, fl
            fl = Rant::FileList.new
            fl.glob "*.t"
            assert_entries all, fl
            fl = Rant::FileList.new
            fl.hide_dotfiles
            fl.glob "*.t"
            assert_entries all - [".a.t"], fl
            fl = Rant::FileList.new
            fl.glob "*a*", "*c*"
            assert_entries ["a.t", "c.t", ".a.t"], fl
            assert fl.entries.index("a.t") < fl.entries.index("c.t")
        end
    end
    def test_to_s
        out = ext_rb_test <<-'EOF', :touch => ["a.c", "b.c"], :return => :stdout
            require 'rant/filelist'
            print "#{Rant::FileList['*.c']}"
        EOF
        assert_equal "a.c b.c", out
    end
    def test_no_dir
        files = ["a/bc/d.t", "xy/f.t", "a.t"]
        out = ext_rb_test <<-'EOF', :touch => files, :return => :stdout
            require 'rant/filelist'
            puts Rant::FileList["**/*.t"].no_dir("bc")
        EOF
        lines = out.split(/\n/)
        assert_equal ["a.t", "xy/f.t"], lines.sort
    end
end
