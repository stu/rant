
require 'test/unit'
require 'rant/rantlib'
require 'fileutils'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestFileList < Test::Unit::TestCase
    def fl(*args)
	Rant::FileList[*args]
    end
    def touch_temp(*args)
	files = args.flatten
	files.each { |f| FileUtils.touch f }
	yield
    ensure
	files.each { |f|
	    File.delete f if File.exist? f
	}
    end
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end
    def test_in_flatten
	touch_temp %w(1.t 2.t) do
	    assert(test(?f, "1.t"))	# test touch_temp...
	    assert(test(?f, "2.t"))
	    assert_equal(2, fl("*.t").size)
	    # see comments in FileList implementation to understand
	    # the necessity of this test...
	    assert_equal(2, [fl("*.t")].flatten.size)
	end
    end
end
