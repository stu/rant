
require 'test/unit'
require 'tutil'

$testDir ||= File.expand_path(File.dirname(__FILE__))

class TestSourceNode < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testDir
    end
    def teardown
	Dir.chdir $testDir
	FileUtils.rm_rf Dir["*.t"]
    end
    def tmp_rf(content = @rf, fn = "rf.t")
	open(fn, "w") { |f| f.write content }
	yield
    ensure
	FileUtils.rm_f fn
    end
    def test_invoke
	@rf = <<-EOF
	gen SourceNode, "a.t"
	EOF
	tmp_rf do
	    out, err = assert_rant("-frf.t")
	    assert(!test(?f, "a.t"))
	    assert(out.strip.empty?)
	    assert(err.strip.empty?)
	end
	tmp_rf do
	    out, err = assert_rant("-frf.t", "a.t")
	    assert(out.strip.empty?)
	    assert(err.strip.empty?)
	end
    end
    def test_deps_empty_array
	@rf = <<-EOF
	gen SourceNode, "a.t" => []
	EOF
	tmp_rf do
	    assert_rant("-frf.t")
	end
    end
    def test_with_deps
	@rf = <<-EOF
	gen SourceNode, "a.t" => %w(b.t c.t)
	EOF
	tmp_rf do
	    assert_rant("-frf.t")
	end
	tmp_rf do
	    assert_rant(:fail, "-frf.t", "b.t")
	end
    end
    def test_as_dependency
	@rf = <<-EOF
	file "a.t" => "b.t" do |t|
	    sys.touch t.name
	end
	gen SourceNode, "b.t" => "c.t"
	EOF
	tmp_rf do
	    out, err = assert_rant(:fail, "-frf.t")
	    assert(out.strip.empty?)
	    assert_match(/\[ERROR\].*no such file.*b\.t/m, err)
	end
	assert(!test(?e, "a.t"))
	FileUtils.touch "b.t"
	tmp_rf do
	    out, err = assert_rant(:fail, "-frf.t")
	    assert(out.strip.empty?)
	    assert_match(/\[ERROR\].*no such file.*c\.t/m, err)
	end
	assert(!test(?e, "a.t"))
	FileUtils.touch "c.t"
	tmp_rf do
	    out, err = assert_rant("-frf.t")
	end
	assert(test(?f, "a.t"))
    end
    def test_timestamps
	@rf = <<-EOF
	file "a.t" => "b.t" do |t|
	    sys.touch t.name
	end
	gen SourceNode, "b.t" => %w(c.t d.t)
	EOF
	FileUtils.touch %w(b.t c.t d.t)
	tmp_rf do
	    assert_rant("-frf.t")
	    assert(test(?f, "a.t"))
	    out, err = assert_rant("-frf.t")
	    assert(out.strip.empty?,
		"no source changed, no update required")
	    old_mtime = File.mtime "a.t"
	    timeout
	    FileUtils.touch "b.t"
	    assert_rant("-frf.t")
	    assert(File.mtime("a.t") > old_mtime)
	    old_mtime = File.mtime "a.t"
	    timeout
	    FileUtils.touch "c.t"
	    assert_rant("-frf.t")
	    assert(File.mtime("a.t") > old_mtime)
	end
    end
    def test_with_block
	@rf = <<-EOF
	gen SourceNode, "a.t" do end
	EOF
	tmp_rf do
	    out, err = assert_rant(:fail, "-frf.t")
	    assert_match(/\[ERROR\].*SourceNode.*block/m, err)
	end
    end
end
