
require 'test/unit'
require 'tutil'
require 'rant/filelist'
require 'rant/import/sys/more'

$test_lib_dir ||= File.expand_path(File.dirname(__FILE__))

class TestRantFileList < Test::Unit::TestCase
    include Rant::TestUtil
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
