
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

# Ensure we run in testproject directory.
$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestSource < Test::Unit::TestCase
    def setup
	Dir.chdir $testDir
    end
    def teardown
	capture_std do
	    assert_equal(0, Rant.run("clean"))
	end
    end
    def test_task_for_source
	capture_std do
	    assert_equal(0, Rant.run("auto.t"))
	end
	assert(test(?f, "auto.rf"))
	assert(test(?f, "auto.t"))
    end
    def test_source_now
	open "rf.t", "w" do |f|
	    f << <<-EOF
	    file "source.rf.t" do |t|
		sys.touch t.name
	    end
	    task :source_now do
		source :n, "source.rf.t"
	    end
	    task :source_now2 do
		sys.touch "source.rf.t"
		source :n, "source.rf.t"
	    end
	    task :mk_source do
		source "source.rf.t"
	    end
	    EOF
	end
	assert_rant("-frf.t", "mk_source")
	assert(test(?f, "source.rf.t"))
	FileUtils.rm "source.rf.t"
	out, err = assert_rant(:fail, "-frf.t", "source_now")
	assert(!test(?f, "source.rf.t"))
	assert_match(/\[ERROR\].*source.*No such file.*source\.rf\.t/im, err)
	assert_rant("-frf.t", "source_now2")
	assert(test(?f, "source.rf.t"))
    end
end
