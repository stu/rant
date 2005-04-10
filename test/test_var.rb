
require 'test/unit'
require 'rant/rantlib'
require 'fileutils'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestVar < Test::Unit::TestCase
    RV = Rant::RantVar
    RS = Rant::RantVar::Space
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
	@rac = Rant::RantApp.new
	@cx = @rac.context
    end
    def teardown
    end
    def test_space
	s = nil
	assert_nothing_raised {
	    s = RS.new
	    assert_nil(s[:a])
	    s[:a] = 1
	    assert_equal(1, s["a"])
	    assert_equal(1, s[:a])
	    s[:b] = "b"
	    assert_equal("b", s.query(:b))
	    assert_same(s[:b], s["b"])
	    assert_same(s.query("b"), s["b"])
	    s.query :a, :Integer, 2
	    assert_equal(2, s[:a])
	    s.query :c, :Integer
	    assert_equal(0, s[:c])
	}
    end
    def test_rac_var_ignore
	assert_equal([], @cx.var(:ignore))
	@cx.var[:ignore] = "CVS"
	assert_equal(%w(CVS), @cx.var["ignore"])
    end
    def test_invalid_for_constraint
	@cx.var :a, :Integer
	assert_equal(0, @cx.var[:a])
	assert_raises(Rant::RantVar::ConstraintError) {
	    @cx.var :a => "x"
	}
	assert_equal(0, @cx.var[:a])
    end
end
