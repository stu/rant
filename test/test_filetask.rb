
require 'test/unit'
require 'rant/rantlib'

$test_filetask_file = File.expand_path(__FILE__)

class TestFileTask < Test::Unit::TestCase
    def setup
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
end
