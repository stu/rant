
require 'test/unit'
require 'rant/rantlib'


class TestLightTask < Test::Unit::TestCase
    def setup
	@app = Rant::RantApp.new %w()
    end
    def teardown
    end
    # shortcut for Rant::LightTask.new
    def lt(*args, &block)
	Rant::LightTask.new(*[@app, args].flatten, &block)
    end
    def test_init
	t = lt :tinit
	assert(t.needed?,
	    "needed? should be true after creation without " +
	    "`needed' block")
	assert(!t.done?)
	assert_equal(t.name, "tinit",
	    "task name should always be a string, despite creation with symbol")
    end
    def test_with_blocks
	run = false
	nr = false
	t = lt :with_blocks do |a|
	    a.needed {
		nr = true
	    }
	    a.act do |l|
		assert_equal(l, t,
		    "act block should get the LightTask as argument")
		run = true
	    end
	end
	assert(t.needed?,
	    "needed block returns true")
	assert(nr,
	    "`needed' block should have been run")
	assert(t.invoke,
	    "invoke should return true because task was needed")
	assert(run,
	    "task should have been run")
	assert(!t.needed?,
	    "task shouldn't be needed? after first run")
    end
    def test_task_with_lighttask_pre
	lt_run = false
	lt_nr = false
	t_run = false
	@app.args.replace %w(t)
	t1 = @app.gen Rant::LightTask, :t1 do |t|
	    t.needed { lt_nr = true }
	    t.act { lt_run = true }
	end
	t = @app.task :t => :t1 do
	    assert(lt_run,
		"LightTask prerequisite should run first.")
	    t_run = true
	end
	assert(t.needed?)
	assert(lt_nr)
	assert(!lt_run,
	    "LightTask#needed? shouldn't run 'act' block")
	assert_equal(0, @app.run)
	assert(t_run)
    end
end
