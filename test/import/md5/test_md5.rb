
require 'test/unit'
require 'tutil'

$test_import_md5_dir ||= File.expand_path(File.dirname(__FILE__))

class TestImportMd5 < Test::Unit::TestCase
    include Rant::TestUtil
    def setup
	# Ensure we run in test directory.
	Dir.chdir($test_import_md5_dir)
    end
    def teardown
	Dir.chdir($test_import_md5_dir)
        Rant::Sys.rm_f Rant::FileList["**/*.rant.meta"]
        Rant::Sys.rm_rf Rant::FileList["*.t", "*.tt"]
    end
    def test_rule_root_and_subdir
        Rant::Sys.mkdir "sub.td"
        Rant::Sys.touch "sub.td/a.tt"
        out, err = assert_rant "sub.td/a.t"
        assert err.empty?
        assert_match(/\bwriting\b.*a\.t\b/, out)
        out, err = assert_rant "sub.td/a.t"
        assert err.empty?
        assert out.empty?
        Dir.chdir "sub.td"
        out, err = assert_rant "-u", "a.t"
        assert err.empty?
        lines = out.split(/\n/)
        assert(lines.size == 1)
        assert(out !~ /writing|a\.t/)
        Dir.chdir $test_import_md5_dir
        out, err = assert_rant "sub.td/a.t"
        assert err.empty?
        assert out.empty?
        assert_rant "autoclean"
        assert !test(?e, "sub.td/a.t")
        assert !test(?e, "sub.td/.rant.meta")
        assert Dir["**/*.rant.meta"].empty?
    ensure
        Dir.chdir $test_import_md5_dir
        Rant::Sys.rm_rf "sub.td"
    end
end
