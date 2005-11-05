
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

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
end
