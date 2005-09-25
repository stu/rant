
require 'test/unit'
require 'tutil'

$test_subdirs2_dir ||= File.expand_path(File.dirname(__FILE__))

class TestSubdirs2 < Test::Unit::TestCase
    include Rant::TestUtil

    def rootdir_rx(subdir=@subdir)
        /^\(root is #$test_subdirs2_dir, in #{subdir}\)$/
    end
    def setup
	# Ensure we run in test directory.
	Dir.chdir($test_subdirs2_dir)
    end
    def teardown
	Dir.chdir($test_subdirs2_dir)
        assert_rant "autoclean"
        assert Rant::FileList["**/*.t*"].shun(".svn").empty?
        assert Rant::FileList["**/.rant.meta"].shun(".svn").empty?
    end
    def test_first
        out, err = assert_rant
        assert err.empty?
        assert_equal "a\n", out
    end
    def test_subdir_task_from_commandline
        out, err = assert_rant "sub1/a"
        assert err.empty?
        assert_equal "(in sub1)\nsub1/a\n", out
    end
    def test_first_in_subdir
        Dir.chdir "sub1"
        out, err = assert_rant
        assert err.empty?
        assert_equal "(root is #$test_subdirs2_dir, in sub1)\nsub1/a\n", out
    end
    def test_directory_in_subdir
        Dir.chdir "sub1"
        out, err = assert_rant "dir.t"
        assert err.empty?
        assert out.include?("mkdir")
        assert test(?d, "dir.t")
        out, err = assert_rant "dir.t"
        assert err.empty?
        assert !out.include?("mkdir")
    end
    def test_root_dir_task_in_subdir_from_commandline
        Dir.chdir "sub1"
        out, err = assert_rant "@a"
        assert err.empty?
        lines = out.split(/\n/)
        assert_match(/^\(root is .*\)$/, lines[0])
        assert lines.size < 4
        assert_equal "a", lines.last
    end
    def test_root_dir_task_from_commandline
        out, err = assert_rant "@a"
        assert err.empty?
        assert_equal "a\n", out
    end
    def test_fail_no_subdir_task
        out, err = assert_rant :fail, "sub00/a.t"
        assert out.empty?
        assert_match(/\[ERROR\]/, err)
        assert_match(/\bsub00\/a\.t\b/, err)
    end
    def test_ensure_read_sub_rant
        Dir.chdir "sub00"
        out, err = assert_rant
        assert test(?f, "a.t")
        assert test(?f, "../a.t")

        out, err = assert_rant :fail, "autoclean"
        assert_equal "(root is #$test_subdirs2_dir, in sub00)\n", out
        assert_rant "@autoclean"
        assert Dir["*.t"].empty?
    end
    def test_show_descriptions
        out, err = assert_rant "-T"
        assert err.empty?
        assert_equal <<EOF, out
rant a        # show full task name
rant sub1/b   # noop
EOF
    end
    def test_show_descriptions_in_subdir
        Dir.chdir "sub1"
        out, err = assert_rant "-T"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 4, lines.size
        assert_match(rootdir_rx("sub1"), lines[0])
        assert_match(/^rant\s+#\s+=>\s+a$/, lines[1])
        assert_match(/^rant b\s+#\s+noop$/, lines[2])
        assert_match(/^rant @a\s+#\s+show full task name$/, lines[3])
    end
    def test_opt_look_up
        in_local_temp_dir "t" do
            out, err = assert_rant :fail
            assert out.empty?
            assert_match(/\[ERROR\].*no rantfile/i, err)
            out, err = assert_rant "--look-up"
            assert err.empty?
            assert_equal "a", out.split(/\n/)[2]
            in_local_temp_dir "t" do
                out, err = assert_rant "--look-up", "a.t"
                assert err.empty?
                lines = out.split(/\n/)
                assert_equal 4, lines.size
                assert_match(rootdir_rx("t/t"), lines[0])
                assert_equal "(in #$test_subdirs2_dir)", lines[1]
                assert_equal "writing to b.t", lines[2]
                assert_equal "writing to t/t/a.t", lines[3]
                assert !test(?e, "../../a.t")
                assert test(?f, "a.t")
                assert test(?f, "../../b.t")
                out, err = assert_rant "--look-up", "a.t"
                assert err.empty?
                lines = out.split(/\n/)
                assert_equal 1, lines.size
                assert_match rootdir_rx("t/t"), lines.first
                out, err = assert_rant "-u", "@autoclean"
                assert !test(?e, "../../b.t")
                assert !test(?e, "a.t")
            end
        end
    end
    def test_opt_look_up_from_subdir
        Dir.chdir "sub1"
        out, err = assert_rant "-u", "dir.t"
        assert err.empty?
        assert out.include?("mkdir")
        assert test(?d, "dir.t")
        out, err = assert_rant "-u", "dir.t"
        assert err.empty?
        assert !out.include?("mkdir")
    end
    def test_opt_cd_parent
        in_local_temp_dir "with space.t" do
            out, err = assert_rant "--cd-parent"
            assert err.empty?
            lines = out.split(/\n/)
            assert_equal 2, lines.size
            assert_equal "(in #$test_subdirs2_dir)", lines[0]
            assert_equal "a", lines[1]
            in_local_temp_dir "a" do
                orig_pwd = Dir.pwd
                out, err = assert_rant "-c", "a.t"
                assert_equal orig_pwd, Dir.pwd
                assert err.empty?
                lines = out.split(/\n/)
                assert_equal 2, lines.size
                assert_equal "(in #$test_subdirs2_dir)", lines[0]
                assert_equal "writing to a.t", lines[1]
                assert test(?f, "../../a.t")
                assert_equal "a.t\n", File.read("../../a.t")
            end
        end
    end
    def test_opt_cd_parent_from_dir_with_rantfile
        out, err = assert_rant "-c"
        assert err.empty?
        assert_equal "a\n", out
    end
    def test_opt_cd_parent_from_subdir
        Dir.chdir "sub1"
        out, err = assert_rant "-c"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 2, lines.size
        assert_equal "(in #$test_subdirs2_dir)", lines[0]
        assert_equal "a", lines[1]
    end
    def test_opt_cd_parent_from_subdir_sub
        Dir.chdir "sub1"
        in_local_temp_dir do
            out, err = assert_rant "-c"
            assert err.empty?
            lines = out.split(/\n/)
            assert_equal 2, lines.size
            assert_equal "(in #$test_subdirs2_dir)", lines[0]
            assert_equal "a", lines[1]
        end
    end
    def test_rant_import
        run_import("-q", "--auto", "rant.t")
        assert_exit
        out = run_ruby("rant.t", "a.t")
        assert_exit
        assert test(?f, "a.t")
        out = run_ruby("rant.t", "a.t")
        assert_exit
        assert out.empty?
        Rant::Sys.safe_ln "rant.t", "sub1"
        Dir.chdir "sub1"
        out = run_ruby("rant.t", "dir.t")
        assert_exit
        assert test(?d, "dir.t")
        out = run_ruby("rant.t", "@autoclean")
        assert !test(?e, "dir.t")
    ensure
        Dir.chdir $test_subdirs2_dir
        Rant::Sys.rm_f Dir["**/rant.t"]
    end
    def test_expand_path_md5_in_sub1
        Dir.chdir "sub1"
        out, err = assert_rant "-imd5", "sub.t"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "sub.t")
        assert_equal "a.t\n", File.read("sub.t")
        out, err = assert_rant "-imd5", "sub.t"
        assert err.empty?
        assert out !~ /writing to/
        assert out !~ /\bcp\b/
        Dir.chdir ".."
        out, err = assert_rant "-imd5", "sub1/sub.t"
        assert err.empty?
        assert out.empty?
        assert_rant "-imd5", "autoclean"
    end
    def test_expand_path
        out, err = assert_rant "sub1/sub.t"
        assert err.empty?
        assert test(?f, "sub1/sub.t")
        assert_equal "a.t\n", File.read("sub1/sub.t")
        out, err = assert_rant "sub1/sub.t"
        assert err.empty?
        assert out.empty?
    end
    def test_define_in_current_subdir
        Dir.chdir "sub00"
        out, err = assert_rant "a"
        assert err.empty?
        assert_equal "sub00/a", out.split(/\n/).last
    end
end
