
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
            fl = Rant::FileList["*.t"]
            assert(fl.each { |fn|
                ary << fn
            }.equal?(fl))
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
            assert fl.include("*.t").equal?(fl)
            assert_entries all, fl
            fl = Rant::FileList.new
            assert fl.glob("*.t").equal?(fl)
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
    def test_exclude
        fl = Rant::FileList(["a.rb", "b.t", "foo_bar"])
        assert fl.exclude("*.rb").equal?(fl)
        assert_entries ["b.t", "foo_bar"], fl

        fl.concat ["b.rb", "a.rb"]
        assert_entries ["b.t", "foo_bar", "b.rb", "a.rb"], fl
    end
    def test_exclude_regexp
        fl = Rant::FileList(["a.rb", "b.t", "foo_bar"])
        fl.exclude %r{_}
        assert_entries ["a.rb", "b.t"], fl

        Rant::Sys.touch "a_b.t"
        fl.include "*.t"
        assert_entries ["a.rb", "b.t", "a_b.t"], fl
    ensure
        Rant::Sys.rm_f "a_b.t"
    end
    def test_exclude_more_args
        fl = Rant::FileList(["a.rb", "b.t", "foo_bar"])
        fl.exclude "*.t", /_/
        assert_entries ["a.rb"], fl
    end
    def test_exclude_dotfiles_always
        in_local_temp_dir do
            Rant::Sys.touch [".a.t", "b.t", "c.t", "a.rb"]
            fl = Rant::FileList[".*.{rb,t}", "*.{rb,t}"]
            assert_entries [".a.t", "b.t", "c.t", "a.rb"], fl
            fl.exclude "*.t"
            assert_entries ["a.rb"], fl
        end
    end
    def test_shun
        fl = Rant::FileList(["a/CVS/b", "CVS", "CVS.rb", "cvs"])
        assert fl.shun("CVS").equal?(fl)
        assert_entries ["CVS.rb", "cvs"], fl
        fl.push "CVS/foo"
        assert_entries ["CVS/foo", "CVS.rb", "cvs"], fl
    end
    def test_exclude_name
        fl = Rant::FileList(["a/CVS/b", "CVS", "CVS.rb", "cvs"])
        assert fl.exclude_name("CVS").equal?(fl)
        assert_entries ["CVS.rb", "cvs"], fl
        fl.push "CVS/foo"
        assert_entries ["CVS/foo", "CVS.rb", "cvs"], fl
    end
    def test_exclude_path
        fl = Rant::FileList(["a.rb", "lib/b.rb", "lib/foo/c.rb"])
        assert fl.exclude_path("lib/*.rb").equal?(fl)
        assert_equal ["a.rb", "lib/foo/c.rb"], fl.entries
    end
    def test_exclude_vs_exclude_path
        fl = Rant::FileList(["a.rb", "lib/b.rb", "lib/foo/c.rb"])
        assert fl.exclude("lib/*.rb").equal?(fl)
        assert_equal ["a.rb"], fl.entries
    end
    def test_ignore
        fl = Rant::FileList(["a/CVS/b", "CVS", "CVS.rb", "cvs"])
        assert fl.ignore("CVS").equal?(fl)
        assert_entries ["CVS.rb", "cvs"], fl
        fl.push "CVS/foo"
        assert_entries ["CVS.rb", "cvs"], fl
    end
    def test_no_dir
        in_local_temp_dir do
            Rant::Sys.mkdir_p ["foo/bar", "baz"]
            Rant::Sys.touch ["foo/bar/xy", "xy"]
            fl = Rant::FileList["**/*"]
            assert_entries ["foo", "foo/bar", "baz", "foo/bar/xy", "xy"], fl
            assert fl.no_dir.equal?(fl)
            assert_entries ["foo/bar/xy", "xy"], fl
        end
    end
    def test_select
        fl1 = Rant::FileList(["a", "b", "c.rb", "d.rb"])
        fl2 = fl1.select { |fn| fn =~ /\.rb$/ }
        assert fl2.kind_of?(Rant::FileList)
        assert_entries ["c.rb", "d.rb"], fl2
        assert_entries ["a", "b", "c.rb", "d.rb"], fl1
        fl2.push "e.rb"
        assert_entries ["c.rb", "d.rb", "e.rb"], fl2
        assert_entries ["a", "b", "c.rb", "d.rb"], fl1
        fl1.push "c"
        assert_entries ["a", "b", "c", "c.rb", "d.rb"], fl1
        assert_entries ["c.rb", "d.rb", "e.rb"], fl2
    end
    def test_map
        fl1 = Rant::FileList(["a.rb", "b.rb"])
        fl2 = fl1.map { |fn| "#{fn}~" }
        assert_entries ["a.rb~", "b.rb~"], fl2
        assert_entries ["a.rb", "b.rb"], fl1
        fl1.push "foo"
        assert_entries ["a.rb", "b.rb", "foo"], fl1
        assert_entries ["a.rb~", "b.rb~"], fl2
    end
    def test_ext
        fl1 = Rant::FileList(["a.c", "b.c"])
        fl2 = fl1.ext("o")
        assert fl2.kind_of?(Rant::FileList)
        assert !fl1.equal?(fl2)
        assert_entries ["a.c", "b.c"], fl1
        assert_entries ["a.o", "b.o"], fl2

        assert_entries ["a.txt"], Rant::FileList(["a"]).ext("txt")
    end
    def test_uniq!
        fl = Rant::FileList(["a", "b", "a"])
        assert fl.uniq!.equal?(fl)
        assert_entries ["a", "b"], fl
        assert fl.uniq!.equal?(fl)
        assert_entries ["a", "b"], fl
    end
    def test_sort!
        fl = Rant::FileList(["a", "c", "b"])
        assert fl.sort!.equal?(fl)
        assert_equal ["a", "b", "c"], fl.entries
        assert fl.sort!.equal?(fl)
        assert_equal ["a", "b", "c"], fl.entries
    end
    def test_map!
        fl = Rant::FileList(["a", "b", "c"])
        assert(fl.map! { |fn| "#{fn}.rb" }.equal?(fl))
        assert_equal ["a.rb", "b.rb", "c.rb"], fl.entries
    end
    def test_reject!
        fl = Rant::FileList(["a.rb", "b", "c", "d.rb"])
        assert(fl.reject! { |fn| fn =~ /\.rb$/ }.equal?(fl))
        assert_equal ["b", "c"], fl.entries
    end
    def resolve
        fl = Rant::FileList(["a", "b"])
        fl2 = nil
        out = capture_stdout do
            fl2 = fl.map { |fn| puts fn; "#{fn}.rb" }
            assert fl2.resolve.equal?(fl2)
        end
        assert_equal "a\nb\n", out
    end
    def test_to_a
        ary = Rant::FileList(["a", "b"]).to_a
        assert ary.kind_of?(Array)
        assert_equal ["a", "b"], ary
    end
    def test_to_ary
        ary = Rant::FileList(["a", "b"]).to_ary
        assert ary.kind_of?(Array)
        assert_equal ["a", "b"], ary
    end

    # TODO: comprehensive testing of FileList#+ operator
    
    def test_size
        assert_equal 2, Rant::FileList(["a", "b"]).size
    end
    def test_empty?
        fl = Rant::FileList(["a", "b"])
        assert !fl.empty?
        fl.exclude "a", "b"
        assert fl.empty?
    end
    def test_join
        fl = Rant::FileList(["a", "b"])
        assert_equal "a b", fl.join
        assert_equal "a\nb", fl.join("\n")
    end
    def test_pop
        fl = Rant::FileList(["a", "b"])
        assert_equal "b", fl.pop
        assert_equal "a", fl.pop
        assert_equal nil, fl.pop
        assert_equal nil, fl.pop
    end
    def test_push
        fl = Rant::FileList(["a", "b"])
        assert fl.push("c").equal?(fl)
        assert_equal ["a", "b", "c"], fl.entries
    end
    def test_shift
        fl = Rant::FileList(["a", "b"])
        assert_equal "a", fl.shift
        assert_equal "b", fl.shift
        assert_equal nil, fl.shift
        assert_equal nil, fl.shift
    end
    def test_unshift
        fl = Rant::FileList(["a", "b"])
        assert fl.unshift("c").equal?(fl)
        assert_equal ["c", "a", "b"], fl.entries
    end
    def test_keep
        fl = Rant::FileList(["b.t"])
        assert fl.keep("a.t").equal?(fl)
        assert_entries ["b.t", "a.t"], fl
        fl.exclude "*.t"
        assert_entries ["a.t"], fl
        fl.ignore "a.t"
        assert_entries ["a.t"], fl
    end
    def test_to_rant_filelist
        fl = Rant::FileList.new
        assert fl.to_rant_filelist.equal?(fl)
    end
    def test_dup
        fl1 = Rant::FileList(["a", "b"])
        fl2 = fl1.dup
        assert !fl1.equal?(fl2)
        fl1.push "c"
        assert_entries ["a", "b", "c"], fl1
        assert_entries ["a", "b"], fl2
    end
    def test_copy
        fl1 = Rant::FileList(["a", "b"])
        fl2 = fl1.copy
        fl1.each { |fn| fn << ".rb" }
        assert_entries ["a.rb", "b.rb"], fl1
        assert_entries ["a", "b"], fl2
    end
    def test_hide_dotfiles
        fl = Rant::FileList.new
        in_local_temp_dir do
            Rant::Sys.touch ["a.t", ".a.t"]
            assert fl.hide_dotfiles.equal?(fl)
            fl.glob "*.t"
            assert_entries ["a.t"], fl
        end
    end
    def test_glob_dotfiles
        fl = Rant::FileList.new
        fl.glob_dotfiles = false
        in_local_temp_dir do
            Rant::Sys.touch ["a.t", ".a.t"]
            assert fl.glob_dotfiles.equal?(fl)
            fl.glob "*.t"
            assert_entries [".a.t", "a.t"], fl
        end
    end
    def test_concat
        fl = Rant::FileList(["a"])
        assert fl.concat(["b", "c"]).equal?(fl)
        assert_equal ["a", "b", "c"], fl.entries
    end
    def test_concat_after_include_with_ignore
        in_local_temp_dir do
            Rant::Sys.touch ["a.1", "a.2", "b.1", "b.2"]
            fl = Rant::FileList.new
            fl.ignore %r{^a.*1$}
            fl.include "*.[12]"
            fl.concat ["abc1", "abc3"]
            assert_entries ["a.2", "b.1", "b.2", "abc3"], fl
            assert_equal 3, fl.entries.index("abc3")
        end
    end
    def test_concat_with_ignore
        fl = Rant::FileList.new.ignore("foo")
        fl.concat ["foo", "bar", "bar/foo", "baz"]
        assert_entries ["bar", "baz"], fl
    end
    def test_to_s
        out = ext_rb_test <<-'EOF', :touch => ["a.c", "b.c"], :return => :stdout
            require 'rant/filelist'
            print "#{Rant::FileList['*.c']}"
        EOF
        assert_equal "a.c b.c", out
    end
    def test_no_dir_with_arg
        files = ["a/bc/d.t", "xy/f.t", "a.t"]
        out = ext_rb_test <<-'EOF', :touch => files, :return => :stdout
            require 'rant/filelist'
            puts Rant::FileList["**/*.t"].no_dir("bc")
        EOF
        lines = out.split(/\n/)
        assert_equal ["a.t", "xy/f.t"], lines.sort
    end
    def test_rant_sys_regular_filename
        out = nil
        if Rant::Env.on_windows?
            out = ext_rb_test <<-'EOF', :return => :stdout
                require 'rant/filelist'
                print Rant::Sys.regular_filename('foo\bar/baz')
            EOF
        else
            out = ext_rb_test <<-'EOF', :return => :stdout
                require 'rant/filelist'
                print Rant::Sys.regular_filename('foo//bar/baz')
            EOF
        end
        assert_equal "foo/bar/baz", out
    end
end
