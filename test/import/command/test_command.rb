
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
    def test_prerequisites_array
        out, err = assert_rant "a2.t"
        assert err.empty?
        assert_file_content "a2.t", "b.t\nc.t\n"
        out, err = assert_rant "a2.t"
        assert err.empty?
        assert out.empty?
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
        out, err = assert_rant "a.out", "rargs=$(prerequisites) $(source) > $(name)"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "a.out", "rargs=$(source) > $(name)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        assert test(?d, "a.in1")
        out, err = assert_rant "a.out", "rargs=$(source) > $(name)"
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
        out, err = assert_rant "-imd5", "a.out", "rargs=$(prerequisites) $(source) > $(name)"
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
    def test_ignore_symbolic_node_var_changes
        Rant::Sys.mkdir "sub.t"
        Rant::Sys.touch ["sub.t/b.in1", "sub.t/b.in2"]
        out, err = assert_rant "sub.t/b.out", "rargs=$(<) $(-) > $(>)"
        assert err.empty?
        assert !out.empty?
	if Rant::Env.on_windows?
	    assert_file_content "sub.t/b.out", "sub.t\\b.in1 sub.t\\b.in2 sub.t\\b.in1", :strip
	else
	    assert_file_content "sub.t/b.out", "sub.t/b.in1 sub.t/b.in2 sub.t/b.in1", :strip
	end
	out, err = assert_rant "sub.t/b.out", "rargs=$(<) $(-) > $(>)"
        assert err.empty?
        assert out.empty?
        Dir.chdir "sub.t"
        out, err = assert_rant "-u", "b.out", "rargs=$(<) $(-) > $(>)"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/\(root\b.*\bsub\.t\)/, lines.first)
	if Rant::Env.on_windows?
	    assert_file_content "b.out", "sub.t\\b.in1 sub.t\\b.in2 sub.t\\b.in1", :strip
	else
	    assert_file_content "b.out", "sub.t/b.in1 sub.t/b.in2 sub.t/b.in1", :strip
	end
    ensure
        Dir.chdir $testImportCommandDir
        Rant::Sys.rm_rf "sub.t"
    end
    def test_do_not_ignore_non_symbolic_node_var_changes
        Rant::Sys.mkdir "sub.t"
        Rant::Sys.touch ["sub.t/b.in1", "sub.t/b.in2"]
        out, err = assert_rant "sub.t/b.out"
        assert err.empty?
        assert !out.empty?
	if Rant::Env.on_windows?
	    assert_file_content "sub.t/b.out", "sub.t\\b.in1 sub.t\\b.in2 sub.t\\b.in1", :strip
	else
	    assert_file_content "sub.t/b.out", "sub.t/b.in1 sub.t/b.in2 sub.t/b.in1", :strip
	end
        out, err = assert_rant "sub.t/b.out"
        assert err.empty?
        assert out.empty?
        Dir.chdir "sub.t"
        out, err = assert_rant "-u", "b.out"
        assert err.empty?
        assert !out.empty?
        lines = out.split(/\n/)
        assert_equal 2, lines.size
        assert_match(/\(root\b.*\bsub\.t\)/, lines.first)
        assert_match(/\bb\.out\b/, lines[1])
	assert_file_content "b.out", "b.in1 b.in2 b.in1", :strip
    ensure
        Dir.chdir $testImportCommandDir
        Rant::Sys.rm_rf "sub.t"
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
    def test_multiple_commands_md5
        out, err = assert_rant "-imd5", "h.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "h.t1", "1\n"
        assert_file_content "h.t2", "2\n"
        assert_file_content "h.t", "1\n2\n"
        meta = File.read ".rant.meta"
        out, err = assert_rant "-imd5", "h.t"
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
    def test_dep_rebuild_no_change_md5
        out, err = assert_rant "-imd5", "t1.t", "t2.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "dep1.t", "a\n"
        assert_file_content "t1.t", "making t1\n"
        assert_file_content "t2.t", "making t2\n"
        out, err = assert_rant "-imd5", "t1.t", "t2.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-imd5", "rc_dep=print 'a'; puts", "t1.t", "t2.t"
        assert err.empty?
        assert out.include?("print")
        assert !out.include?("making t2")
        assert !out.include?("making t1")
    end
    def test_dep_rebuild_same_content_md5
        out, err = assert_rant "-imd5", "t1.t", "t2.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "dep1.t", "a\n"
        assert_file_content "t1.t", "making t1\n"
        assert_file_content "t2.t", "making t2\n"
        out, err = assert_rant "-imd5", "t1.t", "t2.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-imd5", "rc_dep=print 'b'; puts", "dep1.t"
        out, err = assert_rant "-imd5", "rc_dep=print 'a'; puts", "t1.t", "t2.t"
        assert err.empty?
        assert out.include?("print")
        assert !out.include?("making t2")
        assert !out.include?("making t1")
    end
    def test_in_subdir
        out, err = assert_rant :fail, "sub1.t/a"
        Rant::Sys.mkdir "sub1.t"
        out, err = assert_rant "sub1.t/a"
        assert err.empty?
        assert !out.empty?
        assert_file_content "sub1.t/a", "sub1.t/a\n"
        out, err = assert_rant "sub1.t/a"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "autoclean"
        assert !test(?e, "sub1.t/a")
        assert test(?d, "sub1.t")
    ensure
        Rant::Sys.rm_rf "sub1.t"
    end
    def test_in_subdir_with_dirtask
        out, err = assert_rant "sub2.t/a"
        assert err.empty?
        assert !out.empty?
        assert test(?d, "sub2.t")
        assert_file_content "sub2.t/a", "sub2.t/a\n"
        out, err = assert_rant "sub2.t/a"
        assert err.empty?
        assert out.empty?
        assert_rant "autoclean"
        assert !test(?e, "sub2.t")
    end
    def test_in_subdir_with_task
        out, err = assert_rant :fail, "sub3/a"
        assert out !~ /task sub3/
        Rant::Sys.mkdir "sub3"
        out, err = assert_rant "sub3/a"
        assert err.empty?
        assert !out.empty?
        assert out !~ /task sub3/
        assert_file_content "sub3/a", "sub3/a\n"
        out, err = assert_rant "sub3/a"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "autoclean"
        assert !test(?e, "sub3/a")
        assert test(?d, "sub3")
        out, err = assert_rant "sub3"
        assert err.empty?
        assert_match(/task sub3/, out)
    ensure
        Rant::Sys.rm_rf "sub3"
    end
    def test_in_subdir_with_task_md5
        out, err = assert_rant :fail, "-imd5", "sub3/a"
        assert out !~ /task sub3/
        Rant::Sys.mkdir "sub3"
        out, err = assert_rant "-imd5", "sub3/a"
        assert err.empty?
        assert !out.empty?
        assert out !~ /task sub3/
        assert_file_content "sub3/a", "sub3/a\n"
        out, err = assert_rant "-imd5", "sub3/a"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-imd5", "autoclean"
        assert !test(?e, "sub3/a")
        assert test(?d, "sub3")
        out, err = assert_rant "-imd5", "sub3"
        assert err.empty?
        assert_match(/task sub3/, out)
    ensure
        Rant::Sys.rm_rf "sub3"
    end
    def test_ignore_for_sig
        out, err = assert_rant "x.t", "a=1", "b=2"
        assert err.empty?
        assert !out.empty?
        assert_file_content "x.t", "1\n2\n"
        out, err = assert_rant "x.t", "a=1", "b=2"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "x.t", "a=1", "b=3"
        assert err.empty?
        assert !out.empty?
        assert_file_content "x.t", "1\n3\n"
        out, err = assert_rant "x.t", "a=1", "b=3"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "x.t", "a=3", "b=3"
        assert err.empty?
        assert out.empty?
        assert_file_content "x.t", "1\n3\n"
    end
    def test_proc_var_with_arg
        out, err = assert_rant "p1.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "p1.t", "p1.t foo value\n"
        out, err = assert_rant "p1.t"
        assert err.empty?
        assert out.empty?
    end
    def test_proc_var_with_arg_md5
        out, err = assert_rant "-imd5", "p1.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "p1.t", "p1.t foo value\n"
        out, err = assert_rant "-imd5", "p1.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-imd5", "change_foo", "p1.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "p1.t", "p1.t changed\n"
        out, err = assert_rant "-imd5", "change_foo", "p1.t"
        assert err.empty?
        assert out.empty?
    end
    def test_proc_var_without_arg
        out, err = assert_rant "p2.t", "p3.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "p2.t", "foo value.\n"
        assert_file_content "p3.t", "foo value..\n"
        out, err = assert_rant "p2.t", "p3.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "p2.t", "p3.t", "inc_foo=on"
        assert err.empty?
        assert !out.empty?
        assert_file_content "p2.t", "foo value..\n"
        assert_file_content "p3.t", "foo value...\n"
        out, err = assert_rant "p2.t", "p3.t", "inc_foo=on"
        assert err.empty?
        assert out.empty?
    end
    def test_delayed_var_interpolation
        out, err = assert_rant "delay.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "delay.t", "foo value\n"
        out, err = assert_rant "delay.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "delay.t"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "change_foo", "delay.t"
        assert err.empty?
        assert !out.empty?
        assert_file_content "delay.t", "changed\n"
        out, err = assert_rant "change_foo", "delay.t"
        assert err.empty?
        assert out.empty?
    end
    # will probably change
    def test_warn_about_hash
        out, err = assert_rant "hash.t"
        assert !out.empty?
        assert err.split(/\n/).size < 3
        assert_match(/\[WARNING\].*`h'/, err)
        assert_match(/\bhash(es)?\b/i, err)
        assert_file_content "hash.t", "", :strip
    end
end
