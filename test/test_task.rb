
require 'test/unit'
require 'rant/rantlib'

$-w = true

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
	task = Rant::Task.new(nil, :test_run, &block)
	task.run
	assert(run, "block should have been executed")
	assert(task.done?, "task is done")
    end

    def test_fail
	block = lambda { |t| t.fail "this task abortet itself" }
	task = Rant::Task.new(nil, :test_fail, &block)
	assert_raise(Rant::TaskFail,
	    "run should throw Rant::TaskFail if block raises Exception") {
	    task.run
	}
	assert(task.fail?)
	assert(task.ran?, "although task failed, it was ran")
    end

    def test_dependant
	r1 = r2 = false
	t1 = Rant::Task.new(nil, :t1) { r1 = true }
	t2 = Rant::Task.new(nil, :t2) { r2 = true }
	t1 << t2
	t1.run
	assert(r1)
	assert(r2, "t1 depends on t2, so t2 should have been run")
	assert(t1.done?)
	assert(t2.done?)
    end

    def test_dependance_fails
	t1 = Rant::Task.new(nil, :t1) { true }
	t2 = Rant::Task.new(nil, :t2) { Rant::Task.fail }
	t1 << t2
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

    def test_dep_on_self
	run = false
	t = Rant.task :t => "t" do |t|
	    run = true
	end
	th = Thread.new { t.run }
	# shouldn't take half a second...
	assert_equal(th.join(0.5), th,
	    "task should remove dependency on itself")
	assert(run,
	    "task should get run despite dependency on itself")
    end
    def test_dep_on_self_in_deplist
	rl = []
	t1 = Rant.task :t1 do |t|
	    rl << t.name
	end
	t2 = Rant.task :t2 do |t|
	    rl << t.name
	end
	t3 = Rant.task :t3 => [:t1, :t3, :t2] do |t|
	    rl << t.name
	end
	th = Thread.new { t3.run }
	# shouldn't take half a second...
	assert_equal(th.join(0.5), th,
	    "task should remove dependency on itself from dependency list")
	assert_equal(rl, %w(t1 t2 t3),
	    "t3 was run and depends on [t1, t2] => run order: t1 t2 t3")
    end
end
