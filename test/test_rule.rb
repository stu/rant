
require 'tutil'
require 'test/unit'
require 'rant/import/sys/more'

# Ensure we run in testproject directory.
$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestRule < Test::Unit::TestCase
    include Rant::TestUtil
    def setup
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
	FileUtils.rm_rf Dir["*.t*"]
	FileUtils.rm_rf Dir["*.lt"]
	FileUtils.rm_rf Dir["*.rt"]
	FileUtils.rm_rf Dir["*.rtt"]
    end
    def test_target_and_source_as_symbol
	FileUtils.touch "r.t"
	FileUtils.touch "r2.t"
	capture_std do
	    assert_equal(0, Rant.run("-frule.rf", "r.tt", "r2.tt"))
	end
	assert(test(?f, "r.t"))
	assert(test(?f, "r2.t"))
    end
    def test_rule_depends_on_rule
	capture_std do
	    assert_equal(0, Rant.run("-frule.rf", "r.tt", "r2.tt"))
	end
	assert(test(?f, "r.t"))
	assert(test(?f, "r2.t"))
    end
    def test_src_block
	FileUtils.touch "r.rtt"
	capture_std do
	    assert_equal(0, Rant.run("-frule.rf", "r.rt"))
	end
	assert(test(?f, "r.rtt"))
	assert(test(?f, "r.rt"))
    end
    def test_src_block_multiple_deps
	capture_std do
	    assert_equal(0, Rant.run("-frule.rf", "r.lt"))
	end
	assert(test(?f, "r.t"))
	assert(test(?f, "r.tt"))
	assert(test(?f, "r.lt"))
    end
    def test_enhance_rule_task
	out, err = assert_rant("-frule.rf", "enhance_t=1", "eh.t")
	assert(test(?f, "eh.t"))
	assert_match(/eh\.t created/, out)
	assert(err !~ /\[WARNING\]|\[ERROR\]/)
    end
    def test_rule_no_block_error
        in_local_temp_dir do
            write_to_file "Rantfile", <<-EOF
            task :a do
                puts "a"
            end
            gen Rule, :o => :c
            EOF
            out, err = assert_rant :fail
            assert out.empty?
            lines = err.split(/\n/)
            assert lines.size < 4
            assert_match(/\[ERROR\].*Rantfile\b.*\b4\b/, lines.first)
            assert_match(/Rule\b.*block required\b/, lines[1])
        end
    end
    def test_empty_extension_target
        in_local_temp_dir do
            Rant::Sys.write_to_file "root.rant", <<-EOF
                gen Rule, "" => ".t" do |t|
                    sys.cp t.source, t.name
                end
            EOF
            Rant::Sys.write_to_file "a.t", "abc\n"
            out, err = assert_rant :tmax_1, "a"
            assert err.empty?
            assert !out.empty?
            assert_file_content "a", "abc\n"
            out, err = assert_rant :tmax_1, "a"
            assert err.empty?
            assert out.empty?
        end
    end
=begin
    # TODO: needs change in prerequisite handling of file tasks
    def test_file_hook_only_file_source
        in_local_temp_dir do
            Rant::Sys.write_to_file "Rantfile", <<-EOF
                gen Rule, :o => :c do |t|
                    sys.cp t.source, t.name
                end
                task "a.c" do |t|
                    puts t.name
                end
                file "b.c" do |t|
                    sys.write_to_file t.name, "ok\n"
                end
                task "d.c" do |t|
                    puts "task for d.c"
                end
                file "d.c" do |t|
                    sys.write_to_file t.name, "ok 2\n"
                end
            EOF
            out, err = assert_rant :fail, "a.o"
            assert out.empty?
            assert_match(/ERROR\b.*\ba\.o/, err)
            assert !test(?e, "a.o")
            out, err = assert_rant "b.o"
            assert err.empty?
            assert !out.empty?
            assert_file_content "b.o", "ok\n"
            out, err = assert_rant "d.o"
            assert err.empty?
            lines = out.split(/\n/)
            assert_equal 1, lines.size
            assert_match(/writing to file/, lines[0])
            assert lines[0] =~ /task for/
            out, err = assert_rant "b.o"
            assert err.empty?
            assert out.empty?
            out, err = assert_rant "d.o"
            assert err.empty?
            assert out.empty?
        end
    end
    def test_file_hook_only_file_source_md5
        in_local_temp_dir do
            Rant::Sys.write_to_file "Rantfile", <<-EOF
                gen Rule, :o => :c do |t|
                    sys.cp t.source, t.name
                end
                task "a.c" do |t|
                    puts t.name
                end
                file "b.c" do |t|
                    sys.write_to_file t.name, "ok\n"
                end
                task "d.c" do |t|
                    puts "task for d.c"
                end
                file "d.c" do |t|
                    sys.write_to_file t.name, "ok 2\n"
                end
            EOF
            out, err = assert_rant :fail, "-imd5", "a.o"
            assert out.empty?
            assert_match(/ERROR\b.*\ba\.o/, err)
            assert !test(?e, "a.o")
            out, err = assert_rant "-imd5", "b.o"
            assert err.empty?
            assert !out.empty?
            assert_file_content "b.o", "ok\n"
            out, err = assert_rant "-imd5", "d.o"
            assert err.empty?
            lines = out.split(/\n/)
            assert_equal 1, lines.size
            assert_match(/writing to file/, lines[0])
            assert lines[0] =~ /task for/
            out, err = assert_rant "-imd5", "b.o"
            assert err.empty?
            assert out.empty?
            out, err = assert_rant "-imd5", "d.o"
            assert err.empty?
            assert out.empty?
        end
    end
=end
if Rant::Env.find_bin("cc") && Rant::Env.find_bin("gcc")
    # Note: we are assuming that "cc" invokes "gcc"!
    def test_cc
	FileUtils.touch "a.t.c"
	capture_std do
	    assert_equal(0, Rant.run("a.t.o", "-frule.rf"))
	end
	assert(test(?f, "a.t.o"))
    end
else
    $stderr.puts "*** cc/gcc not available, less rule tests ***"
end
    def test_abs_path_source
        FileUtils.touch "abs_rule_test.et"
        abs_target_path = File.expand_path "abs_rule_test.ett"
        out, err = assert_rant("-frule.rf", abs_target_path)
        assert test(?f, abs_target_path)
        out, err = assert_rant("-frule.rf", abs_target_path)
        assert out.empty?
    ensure
        Rant::Sys.rm_f ["abs_rule_test.et", "abs_rule_test.ett"]
    end
end
