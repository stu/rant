
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
end
