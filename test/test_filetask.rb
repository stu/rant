
require 'test/unit'
require 'rant/rantlib'

class TestFileTask < Test::Unit::TestCase
    def setup
    end
    def teardown
    end

    def test_single_dep
	tr = false
	t = Rant.task :t do
	    tr = true
	end
	run = false
	f = Rant.file "testfile" => :t do
	    run = true
	end
	f.run
	assert(tr)
	assert(run)
    end
    def test_prerequisites
	Rant.file "a" do
	    true
	end
	Rant.file "b" do
	    true
	end
	f = Rant.file "c" => %w(a b) do |t|
	    assert_equal(t.prerequisites, %w(a b),
		"prerequisites should always be an array of _strings_")
	    true
	end
	f.run
    end
end
