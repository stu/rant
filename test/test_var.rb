
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
	    @cx.var[:a] = "x"
	}
	assert_equal(0, @cx.var[:a])
    end
    def test_env
	ENV["RANT_TEST_VAL"] = "val"
	@cx.var.env "RANT_TEST_VAL"
	assert_equal("val", @cx.var["RANT_TEST_VAL"])
	assert_equal("val", @cx.var("RANT_TEST_VAL"))
	@cx.var[:RANT_TEST_VAL] = "new"
	assert_equal("new", @cx.var["RANT_TEST_VAL"])
	assert_equal("new", ENV["RANT_TEST_VAL"])
	env_val2 = ENV["RANT_TEST_VAL2"]
	@cx.var["RANT_TEST_VAL2"] = "val2"
	assert_equal(env_val2, ENV["RANT_TEST_VAL2"])
	assert_equal("val2", @cx.var("RANT_TEST_VAL2"))
    end
    def test_late_env
	@cx.var "rtv3" => "val3"
	@cx.var.env "rtv3", "rtv4"
	assert_equal("val3", @cx.var["rtv3"])
	assert_equal("val3", ENV["rtv3"])
	ENV["rtv4"] = "val4"
	assert_equal("val4", @cx.var["rtv4"])
    end
    def test_env_with_array
	@cx.var "rtv6" => "val6"
	@cx.var.env %w(rtv6 rtv7)
	assert_equal("val6", @cx.var["rtv6"])
	assert_equal("val6", ENV["rtv6"])
	ENV["rtv7"] = "val7"
	assert_equal("val7", @cx.var["rtv7"])
    end
    def test_defaults
	@rac.args.replace %w(-fvar.rf)
	capture_std do
	    assert_equal(0, @rac.run)
	end
	assert(test(?f, "default_1.t"))
	assert(test(?f, "default_2.t"))
	capture_std do
	    assert_equal(0, Rant::RantApp.new(%w(-fvar.rf clean)).run)
	end
    end
    def test_override
	@rac.args.replace %w(v1=val1.t v2=val2.t -fvar.rf)
	capture_std do
	    assert_equal(0, @rac.run)
	end
	assert(test(?f, "val1.t"))
	assert(test(?f, "default_2.t"))
	capture_std do
	    assert_equal(0, Rant::RantApp.new(%w(-fvar.rf clean)).run)
	end
    end
end
