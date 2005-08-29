
require 'test/unit'
require 'tutil'

$test_filetask_file = File.expand_path(__FILE__)
$test_dir ||= File.dirname($test_filetask_file)

class TestFileTask < Test::Unit::TestCase
    include Rant::TestUtil

    def setup
        Dir.chdir $test_dir
        @rant = Rant::RantApp.new
    end
    def test_needed_non_existent
	run = false
	t = Rant::FileTask.new(@rant, "non_existent") { run = true }
	assert(t.needed?,
	    "`non_existent' doesn't exist, so filetask is needed")
	assert(!run,
	    "only FileTask#needed? was called, which shouldn't run task block")
    end
    def test_needed_no_dep
	run = false
	t = Rant.rac.file $test_filetask_file do
	    run = true
	end
	assert(!t.needed?,
	    "file exists and has no prerequisite, so needed? should return false")
	assert(!run)
    end
=begin
    commented out due to a semantics change in 0.4.5
    def test_single_dep
	tr = false
	t = Rant.rac.task :t do
	    tr = true
	end
	run = false
	f = Rant.rac.file "testfile" => :t do
	    run = true
	end
	f.invoke
	assert(tr)
	assert(run)
    end
=end
    def test_prerequisites
	Rant.rac.file "a" do
	    true
	end
	Rant.rac.file "b" do
	    true
	end
	f = Rant.rac.file "c" => %w(a b) do |t|
	    assert_equal(t.prerequisites, %w(a b),
		"prerequisites should always be an array of _strings_")
	    true
	end
	f.invoke
    end
    def test_no_invoke_task_dep
        write_to_file "print_name.t", "b\n"
        out, err = assert_rant "depends_name.t"
        assert err.empty?
        assert test(?f, "depends_name.t")
        assert_equal "b\na\n", File.read("depends_name.t")
        assert_match(/writing.*depends_name\.t/, out)
        assert !out.include?("print_name.t"),
            "file task mustn't invoke task as prerequisite"
        out, err = assert_rant "depends_name.t"
        assert err.empty?
        assert out.empty?
        assert test(?f, "depends_name.t")
        assert_equal "b\na\n", File.read("depends_name.t")
    ensure
        Rant::Sys.rm_f %w(print_name.t depends_name.t)
    end
    def test_no_invoke_task_dep_md5
        write_to_file "print_name.t", "b\n"
        out, err = assert_rant "-imd5", "depends_name.t"
        assert err.empty?
        assert test(?f, "depends_name.t")
        assert_equal "b\na\n", File.read("depends_name.t")
        assert_match(/writing.*depends_name\.t/, out)
        assert !out.include?("print_name.t"),
            "file task mustn't invoke task as prerequisite"
        out, err = assert_rant "-imd5", "depends_name.t"
        assert err.empty?
        assert out.empty?
        assert test(?f, "depends_name.t")
        assert_equal "b\na\n", File.read("depends_name.t")
    ensure
        Rant::Sys.rm_f %w(auto.rf .rant.meta print_name.t depends_name.t)
        Rant::Sys.rm_f Dir["*.t"]
    end
end
