
require 'test/unit'
require 'rant/rantlib'
require 'tutil'
require 'fileutils'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestClean < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testDir) unless Dir.pwd == $testDir
    end
    def teardown
    end
    def layout_project1
	FileUtils.mkdir "p1.t"
	Dir.chdir "p1.t" do
	    open("Rantfile", "w") { |f|
		f << <<-EOF
		import "clean"
		task :mk_junk => "sub1.t/mk_junk" do
		    sys.touch %w(a1.t a2.t b1.t b2.t)
		    sys.mkdir %w(sa.t sb.t)
		    sys.touch %w(sa.t/1 sb.t/1)
		end
		gen Clean
		var[:clean].include "*a*.t"
		subdirs "sub1.t"
		EOF
	    }
	end
	FileUtils.mkdir "p1.t/sub1.t"
	Dir.chdir "p1.t/sub1.t" do
	    open("Rantfile", "w") { |f|
		f << <<-EOF
		import "clean"
		task :mk_junk do
		    sys.touch %w(a1.t a2.t b1.t b2.t)
		    sys.mkdir %w(sa.t sb.t)
		end
		gen Clean
		var[:clean].include "*b*.t"
		EOF
	    }
	end
    end
    def cleanup_project1
	FileUtils.rm_rf "p1.t"
    end
    def test_project1
	layout_project1
	assert(test(?d, "p1.t"))
	Dir.chdir "p1.t"
	assert(test(?f, "Rantfile"))
	assert(test(?d, "sub1.t"))
	assert(test(?f, "sub1.t/Rantfile"))

	capture_std do
	    assert_equal(0, Rant::RantApp.new.run)
	end
	files = %w(a1.t a2.t b1.t b2.t sub1.t/a1.t
		    sub1.t/a2.t sub1.t/b1.t sub1.t/b2.t)
	dirs = %w(sa.t sb.t)
	files.each { |f| assert(test(?f, f)) }
	dirs.each { |f| assert(test(?d, f)) }
	capture_std do
	    assert_equal(0, Rant::RantApp.new("clean").run)
	end
	%w(sa.t a1.t a2.t sub1.t/b1.t sub1.t/b2.t).each { |f|
	    assert(!test(?e, f))
	}
	%w(sb.t b1.t b2.t sub1.t/a1.t sub1.t/a2.t).each { |f|
	    assert(test(?e, f))
	}
	Dir.chdir "sub1.t"
	FileUtils.rm_rf %w(sa.t sb.t)
	capture_std do
	    assert_equal(0, Rant::RantApp.new.run)
	end
	%w(a1.t a2.t b1.t b2.t).each { |f| assert(test(?f, f)) }
	%w(sa.t sb.t).each { |f| assert(test(?d, f)) }
	capture_std do
	    assert_equal(0, Rant::RantApp.new("clean").run)
	end
	%w(b1.t b2.t sb.t).each { |f| assert(!test(?e, f)) }
	%w(a1.t a2.t sa.t).each { |f| assert(test(?e, f)) }

    ensure
	Dir.chdir $testDir
	cleanup_project1
    end
    def layout_project2
	FileUtils.mkdir "p2.t"
	FileUtils.mkdir "p2.t/c.t"
	FileUtils.touch "p2.t/c.t/data"
	Dir.chdir "p2.t"
	open("Rantfile", "w") { |f|
	    f << <<-EOF
	    import "autoclean"
	    task :mk_junk => %w(a.t b.t/c.t/d.t) do
		sys.touch "mk_junk.t"
	    end
	    gen AutoClean
	    file "a.t" do |t|
		sys.touch t.name
	    end
	    gen Directory, "b.t/c.t"
	    gen Directory, "c.t", "a"
	    file "c.t/a/b" => "c.t/a" do
		sys.touch t.name
	    end
	    file "b.t/c.t/d.t" => "b.t/c.t" do |t|
		sys.touch t.name
	    end
	    var[:autoclean].include "mk_junk.t"
	    var[:autoclean].include "nix.t"
	    EOF
	}
    end
    def cleanup_project2
	FileUtils.rm_rf "p2.t"
    end
    def test_project2_autoclean
	layout_project2
	capture_std do
	    assert_equal(0, Rant::RantApp.new.run)
	end
	%w(a.t b.t/c.t/d.t mk_junk.t).each { |f| assert(test(?e, f)) }
	capture_std do
	    assert_equal(0, Rant::RantApp.new("autoclean").run)
	end
	%w(a.t b.t/c.t/d.t c.t/a mk_junk.t).each { |f| assert(!test(?e, f)) }
	assert(test(?d, "c.t"))
	assert(test(?f, "c.t/data"))
	capture_std do
	    assert_equal(1, Rant::RantApp.new("clean").run)
	end
    ensure
	cleanup_project2
    end
end
