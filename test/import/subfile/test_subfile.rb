
require 'test/unit'
require 'tutil'

$testImportSubFileDir ||= File.expand_path(File.dirname(__FILE__))

class TestSubFile < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testImportSubFileDir)
    end
    def teardown
	FileUtils.rm_rf Dir["*.t"]
    end
    def test_run_cmd
	assert_rant("sub.t/file")
	assert(test(?d, "sub.t"))
	assert(test(?f, "sub.t/file"))
    end
    def test_desc
	out, err = assert_rant("--tasks")
	assert_match(%r{sub2\.t/file\s*#.*some subfile}, out)
    end
    def test_no_block
	assert_rant("sub2.t/file")
	assert(test(?d, "sub2.t"))
	assert(!test(?e, "sub2.t/file"))
    end
    def test_fail_no_basedir
	assert_rant(:fail, "sub3.t/file")
	assert(!test(?e, "sub3.t"))
	assert(!test(?e, "sub3.t/file"))
    end
    def test_basedir
	FileUtils.mkdir "sub3.t"
	assert_rant("sub3.t/file")
	assert(test(?d, "sub3.t"))
	assert(test(?f, "sub3.t/file"))
    end
    def test_dirtask_exists
	assert_rant("sub.t/file2")
	assert(test(?d, "sub.t"))
	assert(test(?f, "sub.t/file2"))
	assert(!test(?e, "sub.t/file"))
    end
    def test_make_two
	assert_rant("sub.t/file", "sub.t/file2")
	assert(test(?f, "sub.t/file"))
	assert(test(?f, "sub.t/file2"))
    end
    def test_two_dirs
	assert_rant("sub4.t/sub/file")
	assert(test(?f, "sub4.t/sub/file"))
    end
    def test_basedir_two_dirs
	FileUtils.mkdir "sub5.t"
	out, err = assert_rant("sub5.t/sub/sub/file")
	assert(!out.strip.empty?)
	assert(test(?f, "sub5.t/sub/sub/file"))
	out, err = assert_rant("sub5.t/sub/sub/file")
	assert(out.strip.empty?)
    end
    def test_make_dir
	assert_rant("sub.t")
	assert(test(?d, "sub.t"))
	assert(!test(?e, "sub.t/file"))
    end
    def test_only_file
	assert_rant("file.t")
	assert(test(?f, "file.t"))
	out, err = assert_rant("file.t")
	assert(out.strip.empty?)
    end
    def test_dependency
	FileUtils.mkdir "sub.t"
	assert_rant("sub.t/sub/file")
	assert(test(?f, "file.t"))
	assert(test(?f, "sub.t/sub/file"))
    end
    def test_dependencies
	assert_rant("a.t")
	assert(test(?f, "file.t"))
	assert(test(?f, "sub.t/file2"))
	assert(test(?f, "a.t"))
    end
    def test_autoclean
	assert_rant("-fautoclean.rf", "sub.t/file")
	assert(test(?f, "sub.t/file"))
	FileUtils.mkdir "sub2.t"
	assert_rant("-fautoclean.rf", "sub2.t/sub.t/file")
	assert(test(?f, "sub2.t/sub.t/file"))
	FileUtils.mkdir "sub3.t"
	assert_rant("-fautoclean.rf", "sub3.t/file")
	assert(test(?f, "sub3.t/file"))
	assert_rant("-fautoclean.rf", "autoclean")
	assert(test(?d, "sub2.t"))
	assert(test(?d, "sub3.t"))
	%w(sub.t sub2.t/sub.t sub3.t/file).each { |f|
	    assert(!test(?e, f),
		"#{f} should have been unlinked by AutoClean")
	}
    end
end
