
require 'test/unit'
require 'tutil'
require 'rant/import/sys/more'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestSysMethods < Test::Unit::TestCase
    include Rant::TestUtil
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir)
        @rant = Rant::RantApp.new
        @cx = @rant.cx
        @sys = @cx.sys
    end
    def teardown
	Dir.chdir($testDir)
        Rant::Sys.rm_rf "t"
        Rant::Sys.rm_rf Rant::FileList["*.t"]
    end
    def test_pwd
        assert_equal Dir.pwd, @sys.pwd
    end
    def test_cd__mkdir_single_str__pwd__rmdir_single_empty_dir
        out, err = capture_std do
            assert_nothing_raised do
                @sys.mkdir "t"
                assert(test(?d, "t"))
                @sys.cd "t"
                assert_equal(File.join($testDir, "t"), @sys.pwd)
                @sys.cd ".."
                assert_equal($testDir, @sys.pwd)
                @sys.rmdir "t"
                assert(!test(?e, "t"))
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 4, lines.size
        assert_match(/mkdir\s+t/, lines[0])
        assert_match(/cd\s+t/, lines[1])
        assert_match(/cd\s+/, lines[2])
        assert_match(/rmdir\s+t/, lines[3])
    end
    def test_cd_absolute_path_with_block
        out, err = capture_std do
            assert_raise(RuntimeError) do
                @sys.mkdir "t"
                @sys.cd(File.join($testDir, "t")) do
                    assert_equal(File.join($testDir, "t"), @sys.pwd)
                    raise
                end
            end
            assert_equal $testDir, @sys.pwd
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_match(/mkdir\s+t/, lines[0])
        assert_match(/cd\s.*t/, lines[1])
    end
    def test_mkdir_array__rmdir_array
        out, err = capture_std do
            assert_nothing_raised do
                @sys.mkdir ["foo.t", File.join($testDir, "bar.t")]
                assert test(?d, "foo.t")
                assert test(?d, "bar.t")
                assert_raise_kind_of(SystemCallError) do
                    @sys.mkdir "foo.t"
                end
                assert test(?d, "foo.t")
                @sys.rmdir [File.join($testDir, "foo.t")]
                assert !test(?e, "foo.t")
                @sys.rmdir @sys["*.t"]
                assert !test(?e, "bar.t")
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 4, lines.size
        assert_match(/mkdir.*foo\.t.*bar\.t/, lines[0])
        assert_match(/mkdir.*foo\.t/, lines[1])
        assert_match(/rmdir.*foo\.t/, lines[2])
        assert_match(/rmdir.*bar\.t/, lines[3])
    end
    def test_plain_cp
        open "a.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        out, err = capture_std do
            assert_nothing_raised do
                @sys.cp "a.t", "b.t"
            end
        end
        assert test(?f, "b.t")
        ca = File.open("a.t", "rb") { |f| f.read }
        cb = File.open("b.t", "rb") { |f| f.read }
        assert_equal ca, "a\nb\rc\n\rd\r\n"
        assert_equal ca, cb
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/cp\s+a\.t\s+b\.t/, lines[0])
    end
    def test_cp_filelist_to_dir
        open "a.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        out, err = capture_std do
            assert_nothing_raised do
                @sys.cp "a.t", "b.t"
                @sys.mkdir "t"
                @sys.cp @sys["*.t"], "t"
            end
        end
        assert test(?f, "b.t")
        assert test(?f, "t/a.t")
        assert test(?f, "t/b.t")
        ca = File.open("t/a.t", "rb") { |f| f.read }
        cb = File.open("t/b.t", "rb") { |f| f.read }
        assert_equal ca, "a\nb\rc\n\rd\r\n"
        assert_equal ca, cb
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 3, lines.size
        assert_match(/cp\s+a\.t\s+b\.t/, lines[0])
        assert_match(/mkdir\s+t/, lines[1])
        assert_match(/cp\s+a\.t\s+b\.t\s+t/, lines[2])
    end
    def test_cp_dir_fail
        out, err = capture_std do
            @sys.mkdir "t"
            assert test(?d, "t")
            assert_raise_kind_of(SystemCallError) do
                @sys.cp "t", "a.t"
            end
        end
        #assert !test(?e, "a.t") # TODO
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal(2, lines.size)
    end
    def test_cp_r_like_cp
        open "a.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        out, err = capture_std do
            assert_nothing_raised do
                @sys.cp_r "a.t", "b.t"
            end
        end
        assert test(?f, "b.t")
        ca = File.open("a.t", "rb") { |f| f.read }
        cb = File.open("b.t", "rb") { |f| f.read }
        assert_equal ca, "a\nb\rc\n\rd\r\n"
        assert_equal ca, cb
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/cp -r\s+a\.t\s+b\.t/, lines[0])
    end
    def test_cp_r
        out, err = capture_std do
            @sys.mkdir "a.t"
            @sys.mkdir "t"
            open "a.t/a", "wb" do |f|
                f << "a\nb\rc\n\rd\r\n"
            end
            @sys.touch "b.t"
            assert_nothing_raised do
                @sys.cp_r @sys["*.t"], "t"
            end
        end
        assert test(?d, "t/a.t")
        ca = File.open("t/a.t/a", "rb") { |f| f.read }
        assert_equal ca, "a\nb\rc\n\rd\r\n"
        assert test(?f, "t/b.t")
        assert test(?d, "a.t")
        assert test(?f, "a.t/a")
        assert test(?f, "b.t")
        lines = out.split(/\n/)
        assert_equal 4, lines.size
        assert_match(/cp -r\s.*t/, lines[3])
    end
    def test_plain_mv
        open "a.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        out, err = capture_std do
            assert_nothing_raised do
                @sys.mv "a.t", "b.t"
            end
        end
        assert test(?f, "b.t")
        assert !test(?e, "a.t")
        cb = File.open("b.t", "rb") { |f| f.read }
        assert_equal cb, "a\nb\rc\n\rd\r\n"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/mv\s+a\.t\s+b\.t/, lines[0])
    end
    def test_mv_dirs_and_files
        out, err = capture_std do
            @sys.mkdir "a.t"
            @sys.mkdir "t"
            @sys.touch "a.t/a"
            @sys.touch "b.t"
            assert_nothing_raised do
                @sys.mv @sys["*.t"], "t"
            end
        end
        assert test(?d, "t/a.t")
        assert test(?f, "t/a.t/a")
        assert test(?f, "t/b.t")
        assert !test(?e, "a.t")
        assert !test(?e, "b.t")
        lines = out.split(/\n/)
        assert_equal 5, lines.size
    end
    def test_plain_rm
        out, err = capture_std do
            @sys.touch "a.t"
            assert test(?f, "a.t")
            @sys.rm "a.t"
            assert !test(?e, "a.t")
            assert_raise_kind_of(SystemCallError) do
                @sys.rm "a.t"
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 3, lines.size
        assert_match(/rm\s+a\.t/, lines[1])
    end
    def test_rm_dir_fail
        out, err = capture_std do
            @sys.mkdir "a.t"
            assert test(?d, "a.t")
            assert_raise_kind_of(SystemCallError) do
                @sys.rm "a.t"
            end
            assert test(?d, "a.t")
        end
    end
    def test_rm_filelist__touch_array
        out, err = capture_std do
            @sys.touch ["a.t", "b.t"]
            assert test(?f, "a.t")
            assert test(?f, "b.t")
            @sys.rm @sys["*.t"]
            assert !test(?e, "a.t")
            assert !test(?e, "b.t")
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 2, lines.size
    end
    def test_rm_f
        out, err = capture_std do
            @sys.touch "a.t"
            assert test(?f, "a.t")
            @sys.rm_f "a.t"
            assert !test(?e, "a.t")
            assert_nothing_raised do
                @sys.rm_f "a.t"
                @sys.rm_f ["a.t", "b.t"]
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 4, lines.size
        assert_match(/rm -f\s+a\.t/, lines[1])
    end
    def test_rm_r_dir__rm_r_fail_not_exist
        out, err = capture_std do
            @sys.mkdir "t"
            @sys.touch "t/a"
            @sys.mkdir "t/sub"
            assert_nothing_raised do
                @sys.rm_r "t"
            end
            assert !test(?e, "t")
            assert_raise_kind_of(SystemCallError) do
                @sys.rm_r "t"
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 5, lines.size
        assert_match(/rm -r\s+t/, lines[3])
    end
    def test_rm_rf
        out, err = capture_std do
            @sys.mkdir "t"
            @sys.touch "t/a"
            @sys.mkdir "t/sub"
            assert_nothing_raised do
                @sys.rm_rf "t"
            end
            assert !test(?e, "t")
            assert_nothing_raised do
                @sys.rm_rf "t"
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 5, lines.size
        assert_match(/rm -rf\s+t/, lines[3])
    end
=begin
    # TODO, but tested indirectly in many other tests anyway
    def test_touch
    end
=end
    def test_safe_ln
        open "a.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        out, err = capture_std do
            assert_nothing_raised do
                @sys.safe_ln "a.t", "b.t"
            end
        end
        assert test(?f, "b.t")
        ca = File.open("a.t", "rb") { |f| f.read }
        cb = File.open("b.t", "rb") { |f| f.read }
        assert_equal ca, "a\nb\rc\n\rd\r\n"
        assert_equal ca, cb
        assert err.empty?
        lines = out.split(/\n/)
        assert lines.size == 1 || lines.size == 2
        assert_match(/(ln|cp)\s+a\.t\s+b\.t/, lines[-1])
        lines[-1] =~ /(ln|cp)\s+a\.t\s+b\.t/
        puts "\n*** hardlinks #{$1 == "ln" ? "" : "not"} supported ***"
        if $1 == "ln"
            assert test_hardlink("a.t", "b.t", :allow_write => true)
        end
    end
    def test_compare_file
        open "a.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        open "b.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        assert @sys.compare_file("a.t", "b.t")
    end
    def test_compare_file_binary?
        # probably not the right test...
        open "a.t", "wb" do |f|
            f << "a\nb\rc\n\rd\r\n"
        end
        open "b.t", "wb" do |f|
            f << "a\nb\rc\n\rd\n"
        end
        assert !@sys.compare_file("a.t", "b.t")
    end
    def test_compare_empty_files
        Rant::Sys.touch "a.t"
        Rant::Sys.touch "b.t"
        assert @sys.compare_file("a.t", "b.t")
    end
    def test_ln__ln_f
        Rant::Sys.write_to_file "a.t", "abc\n"
        e = nil
        out, err = capture_std do
            begin
                @sys.ln "a.t", "b.t"
            rescue Exception => e
                puts "\n*** hard links not supported ***"
                assert(e.kind_of?(SystemCallError) ||
                       e.kind_of?(NotImplementedError), 
                    "exception Errno::EOPNOTSUPP " +
                    "expected but #{e.class} risen")
            end
        end
        if e
            assert !test(?e, "b.t")
        else
            #assert test(?-, "b.t", "a.t")
            assert test_hardlink("a.t", "b.t")
            assert !test(?l, "b.t") # shouldn't be necessary
            assert_file_content "b.t", "abc\n"
            assert err.empty?
            lines = out.split(/\n/)
            assert_equal 1, lines.size
            assert_match(/ln\s+a\.t\s+b\.t/, lines[0])

            # further tests

            Rant::Sys.mkdir "t"
            out, err = capture_std do
                assert_nothing_raised do
                    @sys.ln "a.t", "t"
                end
            end
            #assert test(?-, "t/a.t", "a.t")
            assert test_hardlink("t/a.t", "a.t")
            assert_file_content "t/a.t", "abc\n"

            Rant::Sys.touch "c.t"
            capture_std do
                assert_raise_kind_of(SystemCallError) do
                    @sys.ln "a.t", "c.t"
                end
            end
            #assert !test(?-, "c.t", "a.t")
            assert !test_hardlink("c.t", "a.t")
            assert_file_content "c.t", ""

            capture_std do
                assert_nothing_raised do
                    @sys.ln_f "a.t", "c.t"
                end
            end
            #assert test(?-, "c.t", "a.t")
            assert test_hardlink("c.t", "a.t")
            assert_file_content "c.t", "abc\n"
        end
    end
    def test_ln_s__ln_sf
        Rant::Sys.write_to_file "a.t", "abc\n"
        e = nil
        out, err = capture_std do
            begin
                @sys.ln_s "a.t", "b.t"
            rescue Exception => e
                puts "\n*** symbolic links not supported ***"
                # TODO: raises NotImplementedError on WinXP/NTFS/ruby-1.8.2
                assert(e.kind_of?(SystemCallError) ||
                       e.kind_of?(NotImplementedError),
                    "exception Errno::EOPNOTSUPP " +
                    "expected but #{e.class} risen")
            end
        end
        if e
            assert !test(?e, "b.t")
        else
            assert test(?l, "b.t")
            assert_file_content "b.t", "abc\n"
            assert err.empty?
            lines = out.split(/\n/)
            assert_equal 1, lines.size
            assert_match(/ln -s\s+a\.t\s+b\.t/, lines[0])

            # further tests

            Rant::Sys.mkdir "t"
            out, err = capture_std do
                assert_nothing_raised do
                    @sys.ln_s File.expand_path("a.t"), "t"
                end
            end
            assert test(?l, "t/a.t")
            assert_file_content "t/a.t", "abc\n"

            Rant::Sys.touch "c.t"
            capture_std do
                assert_raise_kind_of(SystemCallError) do
                    @sys.ln_s "a.t", "c.t"
                end
            end
            assert !test(?l, "c.t")
            assert_file_content "c.t", ""

            capture_std do
                assert_nothing_raised do
                    @sys.ln_sf "a.t", "c.t"
                end
            end
            assert test(?l, "c.t")
            assert_file_content "c.t", "abc\n"
        end
    end
    def test_uptodate?
        assert !@sys.uptodate?("a.t", [])
        Rant::Sys.touch "a.t"
        assert @sys.uptodate?("a.t", [])
        timeout
        Rant::Sys.touch "b.t"
        assert !@sys.uptodate?("a.t", @sys.glob("*.t").exclude("a.t"))
        Rant::Sys.touch ["a.t", "b.t"]
        assert !@sys.uptodate?("a.t", ["b.t"])
        timeout
        Rant::Sys.touch "a.t"
        assert @sys.uptodate?("a.t", ["b.t"])
        Rant::Sys.touch "c.t"
        assert !@sys.uptodate?("a.t", ["c.t", "b.t"])
    end
    def test_install
        # TODO: more tests, especially option testing
        Rant::Sys.mkdir "t"
        Rant::Sys.mkdir ["lib.t", "lib.t/a"]
        Rant::Sys.touch ["lib.t/a.s", "lib.t/a/b.s"]
        out, err = capture_std do
            Rant::Sys.cd "lib.t" do
                assert_nothing_raised do
                    @sys.install @sys.glob("**/*").no_dir, "#$testDir/t"
                end
            end
        end
        assert err.empty?
        assert !out.empty?  # TODO: more accurate
        assert_file_content "t/a.s", ""
        assert_file_content "t/b.s", ""
    end
    def test_mkdir_p
        out, err = capture_std do
            assert_nothing_raised do
                @sys.mkdir_p "t"
                assert test(?d, "t")
                @sys.mkdir_p "t/t1/t2/t3"
                assert test(?d, "t/t1/t2/t3")
                @sys.mkdir_p ["#$testDir/tt/a", "ttt/a/b/c"]
                assert test(?d, "tt/a")
                assert test(?d, "ttt/a/b/c")
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 3, lines.size
        assert_match(/mkdir -p\s+t/, lines[0])
    ensure
        Rant::Sys.rm_rf ["tt", "ttt"]
    end
    def test_chmod
        # TODO
        Rant::Sys.touch "a.t"
        out, err = capture_std do
            assert_nothing_raised do
                @sys.chmod 0755, "a.t"
            end
        end
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal 1, lines.size
        assert_match(/chmod 0?755 a\.t/, lines[0])
        s = File.stat("a.t")
        unless (s.mode & 0777) == 0755
            puts "\n***chmod 0755 not fully functional (actual: #{s.mode.to_s(8)}) ***"
        end
    end
    def test_write_to_file
        @cx.import "sys/more"
        capture_std do
            # TODO: specialize exception class
            assert_raise_kind_of(StandardError) do
                @sys.write_to_file "a.t", Object.new
            end
        end
        assert !test(?e, "a.t")
        out, err = capture_std do
            @sys.write_to_file "a.t", "hello\n"
        end
        assert_file_content "a.t", "hello\n"
    end
end
