
require 'test/unit'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestAction < Test::Unit::TestCase
    include Rant::TestUtil
    def setup
        # Ensure we run in test directory.
        Dir.chdir($testDir)
    end
    def teardown
        Rant::Sys.rm_f Rant::FileList["*.t", "*.tt", "action.t.rant"]
    end
    def test_one_arg_regex
        out, err = assert_rant "-faction.rant", "a.t", "b.t"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 4, lines.size
        assert_equal 'executing action: rx /\.t$/', lines[0]
        assert_match(/action\.t\.rant/, lines[1])
        assert_match(/touch\s+a\.t/, lines[2])
        assert_match(/touch\s+b\.t/, lines[3])
    end
    def test_one_arg_regex_remove_action
        out, err = assert_rant :tmax_1, :fail, "-faction.rant", "a.t", "b.t", "c.t"
        #assert err.empty?
        lines = out.split(/\n/)
        assert_equal 4, lines.size
        assert_equal 'executing action: rx /\.t$/', lines[0]
        assert_match(/action\.t\.rant/, lines[1])
        assert_match(/touch\s+a\.t/, lines[2])
        assert_match(/touch\s+b\.t/, lines[3])
    end
    def test_no_execute
        out, err = assert_rant "-faction.rant", "b.tt"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/touch\s+b\.tt/, lines[0])
        out, err = assert_rant "-faction.rant", "b.tt"
        assert err.empty?
        assert out.empty?
    end
    def test_pwd
        Rant::Sys.mkdir "sub.t"
        Rant::Sys.write_to_file "sub.t/sub.rant", <<-EOF
            task :a do
                puts Dir.pwd
                make "a.t" rescue nil
                puts Dir.pwd
                make "@a.t"
            end
        EOF
        out, err = assert_rant "-faction.rant", "sub.t/a"
        assert err !~ /ERROR/i
        lines = out.split(/\n/)
        assert_equal 7, lines.size
        assert_match(/\bin\b/, lines[0])
        subdir = File.join($testDir, "sub.t")
        assert_equal(subdir, lines[1])
        assert_match(/executing action: rx/, lines[2])
        assert_match(/\bin\b/, lines[3])
        assert_match(/action\.t\.rant/, lines[4])
        assert_equal(subdir, lines[5])
        assert_match(/touch\s+a\.t/, lines[6])
        assert_file_content "a.t", ""
        assert test(?f, "action.t.rant")
        assert !test(?e, "sub.t/action.t.rant")
    ensure
        Dir.chdir($testDir)
        Rant::Sys.rm_rf "sub.t"
    end
end
