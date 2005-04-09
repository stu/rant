
require 'test/unit'
require 'rant/rantlib'
require 'fileutils'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestFileList < Test::Unit::TestCase
    def fl(*args, &block)
	Rant::FileList.new(*args, &block)
    end
    def touch_temp(*args)
	files = args.flatten
	files.each { |f| FileUtils.touch f }
	yield if block_given?
    ensure
	files.each { |f|
	    File.delete f if File.exist? f
	}
    end
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end
    def test_in_flatten
	touch_temp %w(1.t 2.t) do
	    assert(test(?f, "1.t"))	# test touch_temp...
	    assert(test(?f, "2.t"))
	    assert_equal(2, fl("*.t").size)
	    # see comments in FileList implementation to understand
	    # the necessity of this test...
	    assert_equal(2, [fl("*.t")].flatten.size)
	end
    end
    def test_exclude_all
	l = fl
	inc_list = %w(
	    CVS_ a/b a
	    ).map! { |f| f.tr "/", File::SEPARATOR }
	not_inc_list = %w(
	    CVS a/CVS a/CVS/b CVS/CVS //CVS /CVS/ /a/b/CVS/c
	    ).map! { |f| f.tr "/", File::SEPARATOR }
	l.concat(not_inc_list + inc_list)
	l.exclude_all "CVS"
	inc_list.each { |f|
	    assert(l.include?(f))
	}
	not_inc_list.each { |f|
	    assert(!l.include?(f))
	}
    end
    def test_ignore
	l = fl
	r = l.ignore "CVS"
	assert_same(l, r)
	inc_list = %w(
	    CVS_ a/b a
	    ).map! { |f| f.tr "/", File::SEPARATOR }
	not_inc_list = %w(
	    CVS a/CVS a/CVS/b CVS/CVS //CVS /CVS/ /a/b/CVS/c
	    ).map! { |f| f.tr "/", File::SEPARATOR }
	l.concat(not_inc_list + inc_list)
	inc_list.each { |f|
	    assert(l.include?(f))
	}
	not_inc_list.each { |f|
	    assert(!l.include?(f))
	}
    end
    def test_ignore_more
	FileUtils.mkdir "fl.t"
	l = fl "fl.t/*", "fl.t", "*.t"
	touch_temp %w(a.t fl.t/CVS fl.t/a~) do
	    l.ignore(/\~$/, "CVS")
	    assert(l.include?("fl.t"))
	    assert(l.include?("a.t"))
	    assert(!l.include?("fl.t/a~"))
	    assert(!l.include?("fl.t/CVS"))
	end
    ensure
	FileUtils.rm_rf "fl.t"
    end
    def test_initialize
	touch_temp %w(1.t 2.tt) do
	    assert(fl("*.t").include?("1.t"),
		'FileList["*.t"] should include 1.t')
	    l = fl("*.t", "*.tt")
	    assert(l.include?("1.t"))
	    assert(l.include?("2.tt"))
	end
    end
    def test_initialize_with_yield
	touch_temp %w(a.t b.t a.tt b.tt) do
	    list = fl { |l|
		l.include "*.t", "*.tt"
		l.exclude "a*"
	    }
	    %w(b.t b.tt).each { |f|
		assert(list.include?(f), "`#{f}' should be included")
	    }
	    %w(a.t a.tt).each { |f|
		assert(!list.include?(f), "`#{f}' shouln't be included")
	    }
	end
    end
    def test_mix_include_exclude
	touch_temp %w(a.t b.t c.t d.t) do
	    list = fl "a*"
	    list.exclude("a*", "b*").include(*%w(b* c* d*))
	    assert(list.exclude_all("d.t").equal?(list))
	    assert(list.include?("b.t"))
	    assert(list.include?("c.t"))
	    assert(!list.include?("a.t"))
	    assert(!list.include?("d.t"))
	end
    end
    def test_exclude_regexp
	touch_temp %w(aa.t a.t a+.t) do
	    list = fl "*.t"
	    list.exclude(/a+\.t/)
	    assert(list.include?("a+.t"))
	    assert(!list.include?("a.t"))
	    assert(!list.include?("aa.t"))
	    assert_equal(1, list.size)

	    list = fl "*.t"
	    list.exclude("a+.t")
	    assert(!list.include?("a+.t"))
	    assert(list.include?("a.t"))
	    assert(list.include?("aa.t"))
	    assert_equal(2, list.size)
	end
    end
    def test_addition
	touch_temp %w(t.t1 t.t2 t.t3) do
	    l = (fl("*.t1") << "a") + fl("*.t2", "*.t3")
	    assert_equal(4, l.size)
	    %w(t.t1 t.t2 t.t3 a).each { |f|
		assert(l.include?(f),
		    "`#{f}' should be included")
	    }
	end
    end
    def test_2addition
	touch_temp %w(1.ta 1.tb 2.t) do
	    l1 = fl "*.ta", "*.t"
	    l2 = fl "1*"
	    l2.exclude "*.ta"
	    l = l1 + l2
	    assert(l.include?("1.ta"))
	    assert_equal(3, l.size)
	end
    end
    def test_glob
	touch_temp %w(t.t1 t.t2) do
	    l = fl "*.t1"
	    l.glob "*.t2"
	    assert_equal(2, l.size)
	    assert(l.include?("t.t1"))
	    assert(l.include?("t.t2"))
	end
    end
    def test_shun
	touch_temp %w(t.t1 t.t2) do
	    l = fl "t.*"
	    l.shun "t.t1"
	    assert_equal(1, l.size)
	    assert(l.include?("t.t2"))
	end
    end
    def test_rac_sys_glob
	rac = Rant::RantApp.new
	cx = rac.context
	FileUtils.mkdir "fl.t"
	l = cx.sys.glob "fl.t/*", "fl.t", "*.t"
	touch_temp %w(a.t fl.t/CVS fl.t/a~) do
	    assert(l.include?("fl.t"))
	    assert(l.include?("a.t"))
	    assert(l.include?("fl.t/a~"))
	    assert(l.include?("fl.t/CVS"))
	end
    ensure
	FileUtils.rm_rf "fl.t"
    end
    def test_rac_sys_glob_ignore
	rac = Rant::RantApp.new
	cx = rac.context
	cx.var["ignore"] = ["CVS", /\~$/]
	FileUtils.mkdir "fl.t"
	l = cx.sys.glob "fl.t/*", "fl.t", "*.t"
	touch_temp %w(a.t fl.t/CVS fl.t/a~) do
	    assert(l.include?("fl.t"))
	    assert(l.include?("a.t"))
	    assert(!l.include?("fl.t/a~"))
	    assert(!l.include?("fl.t/CVS"))
	end
    ensure
	FileUtils.rm_rf "fl.t"
    end
    def test_sys_glob_late_ignore
	rac = Rant::RantApp.new
	cx = rac.context
	FileUtils.mkdir "fl.t"
	l = cx.sys["fl.t/*", "fl.t", "*.t"]
	touch_temp %w(a.t fl.t/CVS fl.t/a~) do
	    cx.var["ignore"] = ["CVS", /\~$/]
	    assert(l.include?("fl.t"))
	    assert(l.include?("a.t"))
	    assert(!l.include?("fl.t/a~"))
	    assert(!l.include?("fl.t/CVS"))
	end
	l[0] = "CVS"
	assert(!l.include?("CVS"))
    ensure
	FileUtils.rm_rf "fl.t"
    end
end
