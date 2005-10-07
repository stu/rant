
require 'test/unit'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestDynamicDependencies < Test::Unit::TestCase
    #include Rant::TestUtil
    def setup
        # Ensure we run in test directory.
        Dir.chdir($testDir)
    end
    def teardown
        assert_rant "-fdyn_dependencies.rf", "autoclean"
        assert Dir["*.t"].empty?
    end
    def test_task
        out, err = assert_rant "-fdyn_dependencies.rf"
        assert err.empty?
        lines = out.split(/\n/)
        assert_equal %w(B C D A), lines
    end
    def test_file
        out, err = assert_rant "-fdyn_dependencies.rf", "a.t"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "a.t")
        assert test(?f, "b.t")
        assert test(?f, "c.t")
        assert test(?f, "d.t")
        out, err = assert_rant "-fdyn_dependencies.rf", "a.t"
        assert err.empty?
        assert out.empty?
    end
    def test_file_md5
        out, err = assert_rant "-imd5", "-fdyn_dependencies.rf", "a.t"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "a.t")
        assert test(?f, "b.t")
        assert test(?f, "c.t")
        assert test(?f, "d.t")
        assert_rant "-imd5", "-fdyn_dependencies.rf", "autoclean"
    end
end
