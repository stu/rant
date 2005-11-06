
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
	    assert_equal(0, Rant::RantApp.new.run(%w(-fvar.rf clean)))
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
	    assert_equal(0, Rant::RantApp.new.run(%w(-fvar.rf clean)))
	end
    end
    def test_is_string
	@rac.var :s, :String
	assert_equal("", @rac.var["s"])
	@rac.var[:s] = "abc"
	assert_equal("abc", @rac.var["s"])
	obj = Object.new
	def obj.to_str
	    "obj"
	end
	assert_nothing_raised { @rac.var[:s] = obj }
	assert_equal("obj", @rac.var[:s])
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:s] = 3
	}
	assert_equal("obj", @rac.var[:s])
    end
    def test_is_integer
	@rac.var(:count => 10).is :Integer
	assert_equal(10, @rac.var[:count])
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:count] = "no_integer"
	}
	assert_equal(10, @rac.var[:count])
    end
    def test_is_integer_in_range
	@rac.var(:count => 10).is 0..20
	assert_equal(10, @rac.var[:count])
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:count] = "no_integer"
	}
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:count] = 21
	}
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:count] = -1
	}
	assert_equal(10, @rac.var[:count])
	@rac.var[:count] = "15"
	assert_equal(15, @rac.var(:count))
    end
    def test_restrict
	assert_equal(nil, @rac.var[:num])
	@rac.var.restrict :num, :Float, -1.1..2.0
	assert_equal(-1.1, @rac.var[:num])
	@rac.var[:num] = "1.5"
	assert_equal(1.5, @rac.var[:num])
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:num] = -1.2
	}
	assert_equal(1.5, @rac.var[:num])
    end
    def test_restrict_cmd
	@rac.args.replace %w(-fvar.rf show_count)
	out, err = capture_std { @rac.run }
	assert_match(/count 1/, out)
    end
    def test_restrict_cmd_change
	@rac.args.replace %w(-fvar.rf count=5 show_count)
	out, err = capture_std { @rac.run }
	assert_match(/count 5/, out)
    end
    def test_restrict_cmd_error
	@rac.args.replace %w(-fvar.rf count=0 show_count)
	out, err = capture_std {
	    assert_equal(1, @rac.run)
	}
	assert_match(/[ERROR]/, err)
    end
    def test_float_range_cmd
	@rac.args.replace %w(-fvar.rf num=5.0 show_num)
	out, err = capture_std do
	    assert_equal(0, @rac.run)
	end
	assert_match(/num 5.0/, out)
    end
    def test_float_range_cmd_invalid
	@rac.args.replace %w(-fvar.rf num=0.0 show_num)
	out, err = capture_std do
	    assert_equal(1, @rac.run)
	end
	assert_match(/[ERROR]/, err)
    end
    def test_float_range_default
	@rac.args.replace %w(-fvar.rf show_num)
	out, err = capture_std do
	    assert_equal(0, @rac.run)
	end
	assert_match(/num 1.1/, out)
    end
    def test_env_to_string
	@rac.var "RT_TO_S", :ToString
	@rac.var.env "RT_TO_S"
	if Rant::Env.on_windows?
	    # very odd on windows: when setting ENV["ABC"]="" you'll
	    # get out ENV["ABC"] == nil
	    assert(ENV["RT_TO_S"] == "" || ENV["RT_TO_S"] == nil)
	    assert(@rac.var["RT_TO_S"] == "" || @rac.var["RT_TO_S"] == nil)
	else
	    assert_equal(ENV["RT_TO_S"], "")
	    assert_equal(@rac.var["RT_TO_S"], "")
	end
	assert_nothing_raised {
	    @rac.var[:RT_TO_S] = "abc"
	    assert_equal("abc", ENV["RT_TO_S"])
	    obj = Object.new
	    def obj.to_s; "obj"; end
	    @rac.var[:RT_TO_S] = obj
	    assert_equal("obj", ENV["RT_TO_S"])
	}
    end
    def test_bool
	@rac.var "true?", :Bool
	assert_equal(false, @rac.var[:true?])
	assert_nothing_raised {
	    @rac.var[:true?] = true
	    assert_equal(true, @rac.var[:true?])
	    @rac.var[:true?] = false
	    assert_equal(false, @rac.var[:true?])
	    @rac.var[:true?] = 1
	    assert_equal(true, @rac.var[:true?])
	    @rac.var[:true?] = 0
	    assert_equal(false, @rac.var[:true?])
	    @rac.var[:true?] = :on
	    assert_equal(true, @rac.var[:true?])
	    @rac.var[:true?] = :off
	    assert_equal(false, @rac.var[:true?])
	    @rac.var[:true?] = "yes"
	    assert_equal(true, @rac.var[:true?])
	    @rac.var[:true?] = "no"
	    assert_equal(false, @rac.var[:true?])
	    @rac.var[:true?] = "true"
	    assert_equal(true, @rac.var[:true?])
	    @rac.var[:true?] = "false"
	    assert_equal(false, @rac.var[:true?])
	    @rac.var[:true?] = "y"
	    assert_equal(true, @rac.var[:true?])
	    @rac.var[:true?] = "n"
	    assert_equal(false, @rac.var[:true?])
	    @rac.var[:true?] = nil
	    assert_equal(false, @rac.var[:true?])
	}
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:true?] = "abc"
	}
	assert_equal(false, @rac.var[:true?])
    end
    def test_bool_shortcut_true
	@rac.var :bs, true
	assert_equal(true, @rac.var[:bs])
	@rac.var[:bs] = false
	assert_equal(false, @rac.var[:bs])
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:bs] = "abc"
	}
	assert_equal(false, @rac.var[:bs])
    end
    def test_bool_shortcut_false
	@rac.var :bs, false
	assert_equal(false, @rac.var[:bs])
	@rac.var[:bs] = "1"
	assert_equal(true, @rac.var[:bs])
	assert_raise(::Rant::RantVar::ConstraintError) {
	    @rac.var[:bs] = "abc"
	}
	assert_equal(true, @rac.var[:bs])
    end
    def test_violation_message
	@rac.args.replace %w(-fvar.rf source_err)
	out, err = capture_std do
	    assert_equal(1, @rac.run)
	end
	assert_match(
	    /source_err\.rf\.t.+2.*\n.*11.+constraint.+integer/i, err)
    ensure
	assert_equal(0, Rant::RantApp.new.run("-fvar.rf", "clean", "-q"))
    end
    def test_rant_import
	@rac.args.replace %w(-fvar.rf show_num)
        run_import "-q", "ant.t"
        assert_exit
        out = run_ruby("ant.t", "-fvar.rf", "show_num")
        assert_exit
	assert_match(/num 1.1/, out)
    ensure
        Rant::Sys.rm_f "ant.t"
    end
end
