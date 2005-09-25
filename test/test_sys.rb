
require 'test/unit'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestSys < Test::Unit::TestCase
    include Rant::Sys
    include Rant::TestUtil

    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir)
    end
    def test_ruby
        cx = Rant::RantApp.new.cx
        block_executed = false
	op = capture_stdout do
	    cx.sys.ruby('-e ""') { |stat|
                block_executed = true
		assert_equal(0, stat)
	    }
	end
        assert(block_executed)
	assert(op =~ /\-e/i,
	    "sys should print command with arguments to $stdout")
    end
    def test_ruby_no_block
        assert(!test(?e, "a.t"))
        out, err = capture_std do
            assert_nothing_raised { ruby '-e', 'open "a.t", "w" do end' }
        end
        assert(test(?f, "a.t"))
    ensure
        FileUtils.rm_f "a.t"
    end
    def test_ruby_exit_code
        cx = Rant::RantApp.new.cx
        block_executed = false
	out, err = capture_std do
	    cx.sys.ruby('-e', 'exit 2') { |stat|
                block_executed = true
		assert_equal(2, stat.exitstatus)
	    }
	end
        assert(block_executed)
        assert(err.empty?)
        assert_match(/. -e exit 2\n\z/m, out)
    end
    def test_ruby_fail
        out, err = capture_std do
            assert_raises(Rant::CommandError) { ruby '-e exit 1' }
        end
    end
    def test_split_all
	pl = split_all("/home/stefan")
	assert_equal(pl.size, 3,
	    "/home/stefan should get split into 3 parts")
	assert_equal(pl[0], "/")
	assert_equal(pl[1], "home")
	assert_equal(pl[2], "stefan")
	pl = split_all("../")
	assert_equal(pl.size, 1,
	    '../ should be "split" into one element')
	assert_equal(pl[0], "..")
    end
    def test_expand_path
        in_local_temp_dir do
            rootdir = Dir.pwd
            write_to_file "root.rant", <<-EOF
                task :a do
                    puts sys.expand_path("@")
                end
                subdirs "sub"
            EOF
            in_local_temp_dir "sub" do
                write_to_file "sub.rant", <<-'EOF'
                    task :a do
                        puts sys.expand_path("@")
                    end
                    task :b do
                        puts sys.expand_path("@/abc")
                    end
                    task :c do
                        puts sys.expand_path("@abc")
                    end
                    task :d do
                        puts sys.expand_path("../abc")
                    end
                    task :e do
                        puts sys.expand_path(nil)
                    end
                    task :f do
                        puts sys.expand_path("@/../abc")
                    end
                    task :g do
                        puts sys.expand_path("a@b")
                    end
                    task :h do
                        puts sys.expand_path("@a@b")
                    end
                    task :i do
                        puts sys.expand_path('\@a@b')
                    end
                    task :j do
                        puts sys.expand_path(nil)
                    end
                EOF
                Dir.chdir ".."
                out, err = assert_rant "a"
                assert_equal rootdir, out.chomp
                out, err = assert_rant "sub/a"
                assert_equal rootdir, out.split(/\n/).last
                Dir.chdir "sub"
                out, err = assert_rant "a"
                assert_equal rootdir, out.split(/\n/).last
                out, err = assert_rant "b"
                assert_equal "#{rootdir}/abc", out.split(/\n/).last
                out, err = assert_rant "c"
                assert_equal "#{rootdir}/abc", out.split(/\n/).last
                out, err = assert_rant "d"
                assert_equal "#{rootdir}/abc", out.split(/\n/).last
                out, err = assert_rant "e"
                assert_equal "#{rootdir}/sub", out.split(/\n/).last
                out, err = assert_rant "f"
                assert_equal "#{File.dirname(rootdir)}/abc", out.split(/\n/).last
                out, err = assert_rant "g"
                assert_equal "#{rootdir}/sub/a@b", out.split(/\n/).last
                out, err = assert_rant "h"
                assert_equal "#{rootdir}/a@b", out.split(/\n/).last
                out, err = assert_rant "i"
                assert_equal "#{rootdir}/sub/@a@b", out.split(/\n/).last
                out, err = assert_rant "e"
                assert_equal "#{rootdir}/sub", out.split(/\n/).last
            end
        end
    end
    # perhaps this test should go into a seperate file
    def test_toplevel
        out = run_rant("-ftoplevel.rf")
	#assert_match(/\btd\b/, out,
	#    "Sys module should print commands to stdout")
	assert_equal(0, $?,
	    "rant -ftoplevel.rf in test/ should be successfull")
    ensure
	File.delete "td" if File.exist? "td"
    end
    # ...ditto
    def test_name_error
	File.open("name_error.rf", "w") { |f|
	    f << "no_var_no_method\n"
	}
	out, err = capture_std do
	    assert_equal(1, Rant.run("-fname_error.rf"))
	end
        lines = err.split(/\n/)
        assert_equal(3, lines.size)
        assert_match(/\bname_error\.rf\b.*\b1\b/, lines[0])
	assert_match(/Name\s*Error/i, lines[1])
    ensure
	File.delete "name_error.rf" if File.exist? "name_error.rf"
    end
    # ...
    def test_standalone
	out = `#{Rant::Sys.sp(Rant::Env::RUBY)} -I#{Rant::Sys.sp(RANT_DEV_LIB_DIR)} standalone.rf`
        assert_exit
	assert_match(/^t_standalone/, out)
    end
    def test_cp_with_filelist
        rac = Rant::RantApp.new
        rac[:quiet] = true
        open "a.t", "w" do |f|
            f.puts "a"
        end
        open "b.t", "w" do |f|
            f.puts "b"
        end
        FileUtils.mkdir "cp.t"
        assert_nothing_raised {
            rac.cx.sys.cp rac.cx.sys["a.t","b.t"], "cp.t"
            assert_equal("a\n", File.read("cp.t/a.t"))
            assert_equal("b\n", File.read("cp.t/b.t"))
        }
    ensure
        FileUtils.rm_rf %w(cp.t a.t b.t)
    end
    def test_sys_with_block
        open "exit_1.t", "w" do |f|
            f << <<-EOF
            exit 1
            EOF
        end
        open "rf.t", "w" do |f|
            f << <<-EOF
            task :rbexit1_block do
                sys Env::RUBY, "exit_1.t" do |status|
                    puts "no success" if status != 0
                    puts status.exitstatus
                end
            end
            task :rbexit1 do
                sys.ruby "exit_1.t"
            end
            EOF
        end
        out, err = assert_rant("-frf.t")
        assert(err.empty?)
        assert_equal(["no success", "1"], out.split(/\n/)[1..-1])
        out, err = assert_rant(:fail, "-frf.t", "rbexit1")
    ensure
        FileUtils.rm_f %w(exit_1.t rf.t)
    end
end
