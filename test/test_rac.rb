
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestRac < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end
    def test_parse_caller_elem_nil
	assert_nothing_raised {
	    ch = Rant::Lib.parse_caller_elem(nil)
	    assert_equal("", ch[:file])
	    assert_equal(0, ch[:ln])
	}
    end
    def test_parse_caller_elem_file_ln
	assert_nothing_raised {
	    ch = Rant::Lib.parse_caller_elem("C:\\foo\\bar:32")
	    assert_equal("C:\\foo\\bar", ch[:file])
	    assert_equal(32, ch[:ln])
	}
    end
    def test_parse_caller_elem_file_ln_meth
	assert_nothing_raised {
	    ch = Rant::Lib.parse_caller_elem("C:\\foo abc\\bar de:32:in nix")
	    assert_equal("C:\\foo abc\\bar de", ch[:file])
	    assert_equal(32, ch[:ln])
	}
    end
    def test_parse_caller_elem_eval
	assert_nothing_raised {
	    ch = Rant::Lib.parse_caller_elem("-e:1")
	    assert_equal("-e", ch[:file])
	    assert_equal(1, ch[:ln])
	}
    end
    def test_parse_caller_elem_file_with_colon_ln_meth
	assert_nothing_raised {
	    ch = Rant::Lib.parse_caller_elem("abc:de:32:in nix")
	    assert_equal("abc:de", ch[:file])
	    assert_equal(32, ch[:ln])
	}
    end
    def test_parse_caller_elem_no_line_number
	assert_nothing_raised {
	    out, err = capture_std do
		ch = Rant::Lib.parse_caller_elem("foo")
		assert_equal("foo", ch[:file])
		assert_equal(0, ch[:ln])
	    end
	}
    end
end
