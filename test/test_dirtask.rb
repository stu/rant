
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

# Ensure we run in testproject directory.
$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestDirTask < Test::Unit::TestCase
    Directory = Rant::Generators::Directory
    def setup
	Dir.chdir($testDir) unless Dir.pwd == $testDir
	@rac = Rant::RantApp.new
    end
    def teardown
	FileUtils.rm_rf Dir["*.t"]
    end
    def args(*args)
	@rac.args.replace(args.flatten)
    end
    def test_return
	dt = @rac.gen Directory, "a.t/b.t"
	assert(Rant::Worker === dt)
	assert_equal("a.t/b.t", dt.name,
	    "`gen Directory' should return task for last directory")
	args "--quiet", "a.t/b.t"
	@rac.run
	assert(test(?d, "a.t"))
	assert(test(?d, "a.t/b.t"))
    end
end
