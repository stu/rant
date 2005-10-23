
require 'test/unit'
require 'tutil'

$testImportCommandDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportCommand < Test::Unit::TestCase
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
if Rant::Env.find_bin("echo")
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
        out, err = assert_rant "a.out", "rcmd=echo $(<) $(source) > $(>)"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "a.out", "rcmd=echo $(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        assert test(?d, "a.in1")
        out, err = assert_rant "a.out", "rcmd=echo  $(source) > $(>)"
        assert err.empty?
        assert out.empty?
        timeout
        Rant::Sys.touch "a.in2"
        out, err = assert_rant "a.out", "rcmd=echo  $(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        out, err = assert_rant "a.out", "rcmd=echo $(source) > $(>)"
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
        out, err = assert_rant "-imd5", "a.out", "rcmd=echo $(<) $(source) > $(>)"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-imd5", "a.out", "rcmd=echo $(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        assert test(?d, "a.in1")
        out, err = assert_rant "-imd5", "a.out", "rcmd=echo  $(source) > $(>)"
        assert err.empty?
        assert out.empty?
        Rant::Sys.write_to_file "a.in2", " "
        out, err = assert_rant "-imd5", "a.out", "rcmd=echo  $(source) > $(>)"
        assert err.empty?
        assert !out.empty?
        assert_file_content "a.out", "a.in1", :strip
        out, err = assert_rant "-imd5", "a.out", "rcmd=echo $(source) > $(>)"
        assert err.empty?
        assert out.empty?
    ensure
        Rant::Sys.rm_f "a.in2"
        assert_rant "autoclean"
        assert !(test(?e, "a.out"))
        assert !(test(?e, "a.in1"))
    end
else
    $stderr.puts "*** `echo' not available, less Command testing ***"
    def test_dummy
        assert true
    end
end
end
