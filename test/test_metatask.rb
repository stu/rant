
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

class TestMetaTask < Test::Unit::TestCase
    def setup
	@app = Rant::RantApp.new %w()
    end
    def teardown
    end
    def test_with_single_task
	run = false
	t = @app.task :t do run = true end
	mt = MetaTask.for_task t
	assert_equal(t.name, mt.name,
	    "MetaTask should have name of contained task(s).")
	if t.needed?
	    assert(mt.needed?,
		"MetaTask should be needed? if only contained task is needed?")
	    mt.invoke
	    assert(run,
		"only contained task was needed?, so it should get invoked")
	else
	    assert(!mt.needed?,
		"MetaTask should return false from needed? because the only contained task does also.")
	end
    end
end
