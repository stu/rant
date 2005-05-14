
require 'test/unit'
require 'tutil'

$testImportCDepDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportCDependenciesOnTheFly < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testImportCDepDir
    end
    def teardown
	Dir.chdir $testImportCDepDir
	FileUtils.rm_f "c_dependencies"
	FileUtils.rm_rf Dir["*.t"]
    end
    def test_opts_without_filename
	open "rf.t", "w" do |f|
	    f << <<-EOF
	    file "bar.t" => "src/bar.c" do |t|
		sys.touch t.name
	    end
	    gen C::Dependencies,
		:sources => sys["src/*.c"],
		:search => "include"
	    source "c_dependencies"
	    EOF
	end
	assert_rant("-frf.t")
	assert(test(?f, "bar.t"))
	out, err = assert_rant("-frf.t")
	assert(out.strip.empty?)
	assert(err.strip.empty?)
	old_mtime = File.mtime "bar.t"
	timeout
	FileUtils.touch "src/abc"
	assert_rant("-frf.t")
	assert_equal(old_mtime, File.mtime("bar.t"))
	timeout
	FileUtils.touch "include/with space.h"
	assert_rant("-frf.t")
	assert(File.mtime("bar.t") > old_mtime)
    end
end
