
require 'test/unit'
require 'tutil'
require 'rant/import'

$test_deprecated_dir ||= File.expand_path(File.dirname(__FILE__))

class TestDeprecated_0_6_0 < Test::Unit::TestCase
    include Rant::TestUtil
    def setup
        Dir.chdir $test_deprecated_dir
    end
    def test_rant_import_option_v
        out, err = capture_std do
            assert_equal(0, Rant::RantImport.new("-v").run)
        end
        if Rant::VERSION > "0.4.8"
            assert_match(/-v\bdeprecated\b.*-V.*--version\b/, err)
        else
            assert err.empty?
        end
        assert_match(/rant-import\s#{Regexp.escape Rant::VERSION}/, out)
    end
end
