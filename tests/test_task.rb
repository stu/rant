
require 'test/unit'
require 'rant/rantlib'

class TestTask < Test::Unit::TestCase
    def setup
    end
    def teardown
    end

    def test_version
	assert(Rant::VERSION.length >= 5)
    end

    def test_run
	run = false
	block = lambda { run = true }
	task = Rant::Task.new(:test_run, &block)
	task.run
	assert(run, "block should have been executed")
	assert(task.done?, "task is done")
    end

    def test_fail
	block = lambda { false }
	task = Rant::Task.new(:test_fail, &block)
	assert_raise(Rant::TaskFail,
	    "run should throw Rant::TaskFail if block returns false") {
	    task.run
	}
	assert(task.fail?)
	assert(task.ran?, "although task failed, it was ran")
    end

    def test_dependant
	r1 = r2 = false
	t1 = Rant::Task.new(:t1) { r1 = true }
	t2 = Rant::Task.new(:t2) { r2 = true }
	t1.prerequisites << t2
	t1.run
	assert(r1)
	assert(r2, "t1 depends on t2, so t2 should have been run")
	assert(t1.done?)
	assert(t2.done?)
    end

    def test_dependance_fails
	t1 = Rant::Task.new(:t1) { true }
	t2 = Rant::Task.new(:t2) { false }
	t1.prerequisites << t2
	assert_raise(Rant::TaskFail,
	    "dependency t2 failed, so t1 should fail too") {
	    t1.run
	}
	assert(t1.fail?)
	assert(t2.fail?)
    end

    def test_task
	run = false
	t = Rant.task :t do |t|
	    run = true
	end
	t.run
	assert(run)
    end
end
