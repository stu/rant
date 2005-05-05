
require 'test/unit'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestAutoSubFileTask < Test::Unit::TestCase
    RG = Rant::Generators
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
	@rac = Rant::RantApp.new
    end
    def teardown
	FileUtils.rm_rf Dir["*.t"]
    end
    def test_create_dir
	@rac.gen RG::Directory, "dir.t"
	blk = lambda { |t| FileUtils.touch t.name }
	@rac.prepare_task("dir.t/file", blk) { |name,pre,blk|
	    Rant::AutoSubFileTask.new(@rac, name, pre, &blk)
	}
	tl = @rac.resolve("dir.t/file")
	assert_equal(1, tl.size)
	ft = tl.first
	assert(ft.prerequisites.empty?)
	@rac.args.replace %w(dir.t/file)
	capture_std do
	    assert_equal(0, @rac.run)
	end
	assert(test(?d, "dir.t"))
	assert(test(?f, "dir.t/file"))
    end
    def test_fail_no_dir
	blk = lambda { |t| FileUtils.touch t.name }
	@rac.prepare_task("dir.t/file", blk) { |name,pre,blk|
	    Rant::AutoSubFileTask.new(@rac, name, pre, &blk)
	}
	@rac.args.replace %w(dir.t/file)
	capture_std do
	    assert_equal(1, @rac.run)
	end
	assert(!test(?e, "dir.t"))
	assert(!test(?e, "dir.t/file"))
    end
    def test_dir_exists
	FileUtils.mkdir "dir.t"
	blk = lambda { |t| FileUtils.touch t.name }
	@rac.prepare_task("dir.t/file", blk) { |name,pre,blk|
	    Rant::AutoSubFileTask.new(@rac, name, pre, &blk)
	}
	@rac.args.replace %w(dir.t/file)
	capture_std do
	    assert_equal(0, @rac.run)
	end
	assert(test(?d, "dir.t"))
	assert(test(?f, "dir.t/file"))
    end
end
