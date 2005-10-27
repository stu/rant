
require 'test/unit'
require 'tutil'

$testImportCommandDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportCommand < Test::Unit::TestCase
    include Rant::TestUtil
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportCommandDir)
    end
    def teardown
	Dir.chdir($testImportCommandDir)
        assert_rant "autoclean"
        assert Rant::FileList["*.t"].empty?
        assert Rant::FileList[".rant.meta"].empty?
    end
    def test_plain_syntax_no_deps
        out, err = assert_rant "b.t"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "b.t")
        assert_equal "b", File.read("b.t").strip
        out, err = assert_rant "b.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "b.t", "btxt=x"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "b.t")
        assert_equal "x", File.read("b.t").strip
        out, err = assert_rant "b.t", "btxt=x"
        assert err.empty?
        assert out.empty?
    end
    def test_plain_syntax_no_deps_md5
        out, err = assert_rant "-imd5", "b.t"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "b.t")
        assert_equal "b", File.read("b.t").strip
        out, err = assert_rant "-imd5", "b.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-imd5", "b.t", "btxt=x"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "b.t")
        assert_equal "x", File.read("b.t").strip
        out, err = assert_rant "-imd5", "b.t", "btxt=x"
        assert err.empty?
        assert out.empty?
    end
    def test_opt_tasks
        out, err = assert_rant "-T"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/\ba\.t\b.*\bBuild a\.t\b/, lines.first)
    end
    def test_block_syntax
        out, err = assert_rant
        assert err.empty?
        lines = out.split(/\n/)
        assert_match(/b\.t/, lines[0])
        assert_match(/c\.t/, lines[1])
        assert_match(/a\.t/, lines[2])
        assert_file_content "a.t", "b.t c.t", :strip
        assert_file_content "b.t", "b", :strip
        assert_file_content "c.t", "", :strip
        out, err = assert_rant
        assert err.empty?
        assert out.empty?
    end
    def test_block_syntax_md5
        out, err = assert_rant "-imd5"
        assert err.empty?
        lines = out.split(/\n/)
        assert_match(/b\.t/, lines[0])
        assert_match(/c\.t/, lines[1])
        assert_match(/a\.t/, lines[2])
        assert_file_content "a.t", "b.t c.t", :strip
        assert_file_content "b.t", "b", :strip
        assert_file_content "c.t", "", :strip
        out, err = assert_rant "-imd5"
        assert err.empty?
        assert out.empty?
        Rant::Sys.write_to_file "d   .t", "abc"
        out, err = assert_rant "-imd5"
        assert err.empty?
        lines = out.split(/\n/)
        assert_match(/c\.t/, lines[0])
        assert_match(/a\.t/, lines[1])
        assert_file_content "a.t", "b.t c.t", :strip
        assert_file_content "c.t", "d   .t", :strip
        out, err = assert_rant "-imd5"
        assert err.empty?
        assert out.empty?
    ensure
        Rant::Sys.rm_f "d   .t"
    end
    def test_enhance
        Rant::Sys.write_to_file "d.t", "d\n"
        out, err = assert_rant "b.t", "be=on"
        assert err.empty?
        assert !out.empty?
        assert_file_content "b.t", "b\nd\n"
        out, err = assert_rant "b.t", "be=on"
        assert err.empty?
        assert out.empty?
    ensure
        Rant::Sys.rm_f "d.t"
    end
    def test_enhance_md5
        Rant::Sys.write_to_file "d.t", "d\n"
        out, err = assert_rant "-imd5", "b.t", "be=on"
        assert err.empty?
        assert !out.empty?
        assert_file_content "b.t", "b\nd\n"
        out, err = assert_rant "-imd5", "b.t", "be=on"
        assert err.empty?
        assert out.empty?
        Rant::Sys.write_to_file "d.t", "e\n"
        out, err = assert_rant "-imd5", "b.t", "be=on"
        assert err.empty?
        assert !out.empty?
        assert_file_content "b.t", "b\ne\n"
        out, err = assert_rant "-imd5", "b.t", "be=on"
        assert err.empty?
        assert out.empty?
        Rant::Sys.write_to_file "b.t", "c\n"
        out, err = assert_rant "-imd5", "b.t", "be=on"
        assert err.empty?
        assert !out.empty?
        assert_file_content "b.t", "b\ne\n"
        out, err = assert_rant "-imd5", "b.t", "be=on"
        assert err.empty?
        assert out.empty?
    ensure
        Rant::Sys.rm_f "d.t"
    end
    def test_rule
        out, err = assert_rant :fail, "a.out"
        assert out.empty?
        lines = err.split(/\n/)
        assert lines.size < 3
        assert_match(/ERROR.*\ba\.out\b/, lines.first)
        assert !test(?e, "a.out")
        assert !test(?e, "a.in1")
        Rant::Sys.write_to_file "a.in2", ""
        assert test(?f, "a.in2")
        out, err = assert_rant "a.out"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1 a.in2 a.in1", :strip
        assert test(?d, "a.in1")
        out, err = assert_rant "a.out", "rargs=$(<) $(source) > $(>)"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "a.out", "rargs=$(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        assert test(?d, "a.in1")
        out, err = assert_rant "a.out", "rargs=$(source) > $(>)"
        assert err.empty?
        assert out.empty?
        timeout
        Rant::Sys.touch "a.in2"
        out, err = assert_rant "a.out", "rargs=  $(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        out, err = assert_rant "a.out", "rargs=$(source) > $(>)"
        assert err.empty?
        assert out.empty?
    ensure
        Rant::Sys.rm_f "a.in2"
        assert_rant "autoclean"
        assert !(test(?e, "a.out"))
        assert !(test(?e, "a.in1"))
    end
    def test_rule_md5
        Rant::Sys.write_to_file "a.in2", ""
        assert test(?f, "a.in2")
        out, err = assert_rant "-imd5", "a.out"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1 a.in2 a.in1", :strip
        assert test(?d, "a.in1")
        out, err = assert_rant "-imd5", "a.out", "rargs=$(<) $(source) > $(>)"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-imd5", "a.out", "rargs=$(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        assert test(?d, "a.in1")
        out, err = assert_rant "-imd5", "a.out", "rargs= $(source) > $(>)"
        assert err.empty?
        assert out.empty?
        Rant::Sys.write_to_file "a.in2", " "
        out, err = assert_rant "-imd5", "a.out", "rargs= $(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        out, err = assert_rant "-imd5", "a.out", "rargs=$(source) > $(>)"
        assert err.empty?
        assert out.empty?
    ensure
        Rant::Sys.rm_f "a.in2"
        assert_rant "autoclean"
        assert !(test(?e, "a.out"))
        assert !(test(?e, "a.in1"))
    end
    def test_with_space
        Rant::Sys.mkdir "with space"
        Rant::Sys.write_to_file "with space/b.t", "content"
        out, err = assert_rant "with space/a.t"
        assert err.empty?
        assert !out.empty?
        content = Rant::Env.on_windows? ?
            "b.t\nwith space\\b.t\n" :
            "b.t\nwith space/b.t\n"
        assert_file_content "with space/a.t", content
        out, err = assert_rant "with space/a.t"
        assert err.empty?
        assert out.empty?
        assert_rant "autoclean"
        ["with space/a.t", "with space/a.t",
            "with space/.rant.meta", "b.t"].each { |fn|
            assert !test(?e, fn)
        }
    ensure
        Rant::Sys.rm_rf "with space"
    end
    def test_sp_var_inline
        out, err = assert_rant "f.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "f.t", "/Ia bc\n"
        out, err = assert_rant "f.t"
        assert err.empty?
        assert out.empty?
    end
    def test_sp_var_inline_path
        out, err = assert_rant "e.t"
        assert err.empty?
        assert !out.empty?
        content = Rant::Env.on_windows? ? "/Ia b\\c\\\n" : "/Ia b/c/\n"
        assert_file_content "e.t", content
        out, err = assert_rant "e.t"
        assert err.empty?
        assert out.empty?
    end
    def test_sp_var_inline_escaped
        out, err = assert_rant "g.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "g.t", "/Ia b/c/\n"
        out, err = assert_rant "g.t"
        assert err.empty?
        assert out.empty?
    end
    def test_sp_var_inline_escaped_md5
        out, err = assert_rant "-imd5", "g.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "g.t", "/Ia b/c/\n"
        out, err = assert_rant "-imd5", "g.t"
        assert err.empty?
        assert out.empty?
    end
    def test_rant_import
        run_import("-q", "--auto", "-imd5", "ant.t")
        assert_exit
        out = run_ruby("ant.t", "-imd5", "e.t")
        assert_exit
        assert !out.empty?
        content = Rant::Env.on_windows? ? "/Ia b\\c\\\n" : "/Ia b/c/\n"
        assert_file_content "e.t", content
        out = run_ruby("ant.t", "-imd5", "e.t")
        assert out.empty?
    ensure
        Rant::Sys.rm_f "ant.t"
    end
    def test_multiple_commands
        out, err = assert_rant "h.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "h.t1", "1\n"
        assert_file_content "h.t2", "2\n"
        assert_file_content "h.t", "1\n2\n"
        meta = File.read ".rant.meta"
        out, err = assert_rant "h.t"
        assert err.empty?
        assert out.empty?
        assert_equal meta, File.read(".rant.meta")
    ensure
        Rant::Sys.rm_f ["h.t1", "h.t2"]
    end
    def test_block_sys_instead_of_string
        out, err = assert_rant :fail, "f_a.t"
        lines = err.split(/\n/)
        assert lines.size < 5
        assert_match(/\[ERROR\]/, err)
        rf_path = File.join($testImportCommandDir, "Rantfile")
        assert_match(/#{Regexp.escape rf_path}\b.*\b13\b/, err)
        assert_match(/block has to return command string/i, err)
        assert_match(/\bf_a\.t\b/, err)
    end
    def test_only_one_arg
        in_local_temp_dir do
            Rant::Sys.write_to_file "root.rant", <<-EOF
                import "command"
                gen Command, "a"
            EOF
            out, err = assert_rant :fail
            lines = err.split(/\n/)
            assert lines.size < 4
            assert_match(/\[ERROR\]/, err)
            assert_match(/\broot\.rant\b.*\b2\b/, err)
            assert_match(/argument/, err)
            assert_match(/\bname\b.*\bcommand\b/, err)
            old_out, old_err = out, err
            out, err = assert_rant :fail, "-T"
            assert_equal old_out, out
            assert_equal old_err, err
        end
    end
end
