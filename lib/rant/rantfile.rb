
require 'rant/rantenv'

module Rant
    class TaskFail < StandardError
	def initialize(*args)
	    @task = args.shift
	    super(args.shift)
	end
	def task
	    @task
	end
	def tname
	    @task ? @task.name : nil
	end
    end

    class Rantfile < Path

	attr_reader :tasks
	
	def initialize(*args)
	    super
	    @tasks = []
	end
    end	# class Rantfile

    # Any +object+ is considered a _task_ if
    # <tt>Rant::Worker === object</tt> is true.
    module Worker

	INVOKE_OPT = {}.freeze

	# Name of the task, this is always a string.
	attr_reader :name
	# A reference to the application this task belongs to.
	attr_reader :app
	# Description for this task.
	attr_accessor :description
	# The rantfile this task was defined in.
	# Should be a Rant::Rantfile instance.
	attr_accessor :rantfile
	# The linenumber in rantfile where this task was defined.
	attr_accessor :line_number
	
	def initialize
	    @description = nil
	    @rantfile = nil
	    @line_number = nil
	end

	# Returns the +name+ attribute.
	def to_s
	    name
	end

	def done?
	    @done
	end

	def needed?
	    !done?
	end

	# +opt+ is a Hash and shouldn't be modified.
	# All objects implementing the Rant::Worker protocol should
	# know about the following +opt+ values:
	# <tt>:needed?</tt>::
	#	Just check if this task is needed.  Should do the same
	#	as calling Worker#needed?
	# <tt>:force</tt>::
	#	Run task action even if needed? is false.
	def invoke(opt = INVOKE_OPT)
	    return needed? if opt[:needed?]
	    self.run if opt[:force] || self.needed?
	end

	def fail msg = nil
	    raise TaskFail.new(self), msg, caller
	end

	def run
	    return unless @block
	    @block.arity == 0 ? @block.call : @block[self]
	end
	private :run

	def hash
	    name.hash
	end

	def eql? other
	    Worker === other and name.eql? other.name
	end
    end

    # A list of tasks with an equal name.
    class MetaTask < Array
	include Worker

	class << self
	    def for_task t
		mt = self.new(t.name)
		mt << t
	    end
	    def for_tasks *tasks
		mt = self.new(tasks.first.name)
		mt.concat tasks
		mt
	    end
	    def for_task_list tasks
		mt = self.new(tasks.first.name)
		mt.concat tasks
		mt
	    end
	end

	def initialize(name)
	    super()
	    @name = name or raise ArgumentError, "no name given"
	end

	def done?
	    all? { |t| t.done? }
	end

	def needed?
	    any? { |t| t.needed? }
	end

	def invoke(opt = INVOKE_OPT)
	    uf = false
	    each { |t| t.invoke(opt) && uf = true }
	    uf
	end

	def description
	    nil
	end
	
	def description=(val)
	    # spit out a warning?
	end

	def rantfile
	    nil
	end
	
	def rantfile=(val)
	    # spit out a warning?
	end

	def line_number
	    0
	end

	def line_number=(val)
	    # spit out a warning?
	end

	def app
	    empty? ? nil : first.app
	end
    end	# class MetaTask

    # A very lightweight task for special purposes.
    class LightTask
	include Worker

	class << self
	    def rant_generate(app, ch, args, &block)
		unless args.size == 1
		    app.abort("LightTask takes only one argument " +
			"which has to be the taskname (string or symbol)")
		end
		app.prepare_task({args.first => [], :__caller__ => ch},
			block) { |name,pre,blk|
		    # TODO: ensure pre is empty
		    # TODO: earlier setting of app?
		    self.new(app, name, &blk)
		}
	    end
	end

	def initialize(app, name)
	    super()
	    @app = app or raise ArgumentError, "no app given"
	    @name = case name
	    when String: name
	    when Symbol: name.to_s
	    else
		raise ArgumentError,
		    "invalid name argument: #{name.inspect}"
	    end
	    @needed = nil
	    @block = nil
	    @done = false

	    yield self if block_given?
	end

	def app
	    @app || Rant.rantapp
	end

	def needed &block
	    @needed = block
	end

	def act &block
	    @block = block
	end

	# Cause task to fail. Usually called from inside the block
	# given to +act+.
	def fail msg = nil
	    raise TaskFail.new(self), msg, caller
	end

	def needed?
	    return false if done?
	    return true if @needed.nil?
	    if @needed.arity == 0
		@needed.call
	    else
		@needed[self]
	    end
	end

	def invoke(opt = INVOKE_OPT)
	    return needed? if opt[:needed?]
	    if opt[:force] && !@done
		self.run
		@done = true
	    else
		if needed?
		    run
		    @done = true
		else
		    false
		end
	    end
	rescue CommandError => e
	    err_msg e.message if app[:err_commands]
	    self.fail
	rescue SystemCallError => e
	    err_msg e.message
	    self.fail
	end
    end	# LightTask

    class Task
	include Worker
	include Console

	T0 = Time.at(0).freeze

	class << self
	    def rant_generate(app, ch, args, &block)
		if args.size == 1
		    UserTask.rant_generate(app, ch, args, &block)
		else
		    app.abort("Task generator currently takes only one" +
			" argument. (generates a UserTask)")
		end
	    end
	end

	def initialize(app, name, prerequisites = [], &block)
	    super()
	    @app = app || Rant.rantapp
	    @name = name or raise ArgumentError, "name not given"
	    @pre = prerequisites || []
	    @pre_resolved = false
	    @block = block
	    @run = false
	    @fail = false
	end

	# Get a list of the *names* of all prerequisites. The
	# underlying list of prerequisites can't be modified by the
	# value returned by this method.
	def prerequisites
	    @pre.collect { |pre| pre.to_s }
	end

	# True if this task has at least one action (block to be
	# executed) associated.
	def has_actions?
	    !!@block
	end

	# Add a prerequisite.
	def <<(pre)
	    @pre_resolved = false
	    @pre << pre
	end

	# Was this task ever run? If this is true, it doesn't
	# necessarily mean that the run was successfull!
	def run?
	    @run
	end

	# True if last task run fail.
	def fail?
	    @fail
	end

	# Task was run and didn't fail.
	def done?
	    run? && !fail?
	end

	# Enhance this task with the given dependencies and blk.
	def enhance(deps = nil, &blk)
	    if deps
		@pre_resolved = false
		@pre.concat deps
	    end
	    if @block
		if blk
		    first_block = @block
		    @block = lambda { |t|
			first_block[t]
			blk[t]
		    }
		end
	    else
		@block = blk
	    end
	end

	def needed?
	    invoke(:needed? => true)
	end

	# Returns a true value if task was acutally run.
	# Raises Rant::TaskFail to signal task (or prerequiste) failure.
	def invoke(opt = INVOKE_OPT)
	    return if done?
	    internal_invoke opt
	end

	def internal_invoke opt, ud_init = true
	    update = ud_init || opt[:force]
	    dep = nil
	    uf = false
	    each_dep { |dep|
		if FileTask === dep
		    handle_filetask(dep, opt) && update = true
		elsif Worker === dep
		    handle_worker(dep, opt) && update = true
		else
		    dep, uf = handle_non_worker(dep, opt)
		    uf && update = true
		    dep
		end
	    }
	    # Never run a task block for a "needed?" query.
	    return update if opt[:needed?]
	    if update
		@run = true
		run
	    end
	    @run
	rescue StandardError => e
	    @fail = true
	    case e
	    when TaskFail: raise
	    when CommandError
		err_msg e.message if app[:err_commands]
	    when SystemCallError
		err_msg e.message
	    else
		err_msg e.message, e.backtrace
	    end
	    self.fail
	end
	private :internal_invoke

	# Called from internal_invoke. +dep+ is a prerequisite which
	# is_a? Worker, but not a FileTask. +opt+ are opts as given to
	# Worker#invoke.
	#
	# Override this method in subclasses to modify behaviour of
	# prerequisite handling.
	#
	# See also: handle_filetask, handle_non_worker
	def handle_worker(dep, opt)
	    dep.invoke opt
	end

	# Called from internal_invoke. +dep+ is a prerequisite which
	# is_a? FileTask. +opt+ are opts as given to Worker#invoke.
	#
	# Override this method in subclasses to modify behaviour of
	# prerequisite handling.
	#
	# See also: handle_worker, handle_non_worker
	def handle_filetask(dep, opt)
	    dep.invoke opt
	end

	# Override in subclass if specific task can handle
	# non-task-prerequisites.
	#
	# Notes for overriding:
	# This method should do one of the two following:
	# [1] Fail with an exception.
	# [2] Return two values: replacement_for_dep, update_required
	#
	# See also: handle_worker, handle_filetask
	def handle_non_worker(dep, opt)
	    err_msg "Unknown task `#{dep}',",
		"referenced in `#{rantfile.path}', line #{@line_number}!"
	    self.fail
	end

	# For each non-worker prerequiste, the value returned from yield
	# will replace the original prerequisite (of course only if
	# @pre_resolved is false).
	def each_dep
	    t = nil
	    if @pre_resolved
		return @pre.each { |t| yield(t) }
	    end
	    @pre.map! { |t|
		if Worker === t
		    # Remove references to self from prerequisites!
		    if t.name == @name
			nil
		    else
			yield(t)
			t
		    end
		else
		    t = t.to_s if Symbol === t
		    if t == @name
			nil
		    else
			# Pre 0.2.6 task selection scheme ###########
			# Take care: selection is an array of tasks
			#selection = @app.select_tasks { |st| st.name == t }
			#############################################

			selection = @app.select_tasks_by_name t
			if selection.empty?
			    # use return value of yield
			    yield(t)
			else
			    selection.each { |st| yield(st) }
			    selection
			end
		    end
		end
	    }
	    @pre.flatten!
	    @pre.compact!
	    @pre_resolved = true
	end
    end	# class Task

    # A UserTask is equivalent to a Task, but it additionally takes a
    # block (see #needed) which is used to determine if it is needed?.
    class UserTask < Task

	class << self
	    def rant_generate(app, ch, args, &block)
		unless args.size == 1
		    app.abort("UserTask takes only one argument " +
			"which has to be like one given to the " +
			"`task' function")
		end
		app.prepare_task(args.first, nil, ch) { |name,pre,blk|
		    self.new(app, name, pre, &block)
		}
	    end
	end

	def initialize(*args)
	    super
	    # super will set @block to a given block, but the block is
	    # used for initialization, not ment as action
	    @block = nil
	    @needed = nil
	    # allow setting of @block and @needed
	    yield self if block_given?
	end

	def act &block
	    @block = block
	end

	def needed &block
	    @needed = block
	end
	
	# We simply override this method and call internal_invoke with
	# the +ud_init+ flag according to the result of a call to the
	# +needed+ block.
	def invoke(opt = INVOKE_OPT)
	    return if done?
	    internal_invoke(opt, ud_init_by_needed)
	end

	private
	def ud_init_by_needed
	    if @needed
		@needed.arity == 0 ? @needed.call : @needed[self]
	    end
	end
    end	# class UserTask

    class FileTask < Task

	def initialize *args
	    super
	    if @name.is_a? Path
		@path = @name
		@name = @path.to_s
	    else
		@path = Path.new @name
	    end
	    @ts = T0
	end

	def path
	    @path
	end

	def needed?
	    return false if done?
	    invoke(:needed? => true)
	end

	def invoke(opt = INVOKE_OPT)
	    return if done?
	    if @path.exist?
		@ts = @path.mtime
		internal_invoke opt, false
	    else
		@ts = T0
		internal_invoke opt, true
	    end
	end

	def handle_filetask(dep, opt)
	    return true if dep.invoke opt
	    # TODO: require dep to exist after invoke?
	    if dep.path.exist?
		#puts "***`#{dep.name}' requires update" if dep.path.mtime > @ts
		dep.path.mtime > @ts
	    end
	end

	def handle_non_worker(dep, opt)
	    dep = Path.new(dep) unless Path === dep
	    unless dep.exist?
		err_msg @app.pos_text(rantfile.path, line_number),
		    "in prerequisites: no such file or task: `#{dep}'"
		self.fail
	    end
	    [dep, dep.mtime > @ts]
	end
    end	# class FileTask

    # An instance of this class is a task to create a _single_
    # directory.
    class DirTask < Task

	class << self

	    # Generate a task for making a directory path.
	    # Prerequisites can be given, which will be added as
	    # prerequistes for the _last_ directory.
	    #
	    # A special feature is used if you provide a block: The
	    # block will be called after complete directory creation.
	    # After the block execution, the modification time of the
	    # directory will be updated.
	    def rant_generate(app, ch, args, &block)
		if args && args.size == 1
		    name, pre, file, ln = app.normalize_task_arg(args.first, ch)
		    self.task(app, ch, name, pre, &block)
		else
		    app.abort(app.pos_text(ch[:file], ch[:ln]),
			"Directory takes one argument, " +
			"which should be like one given to the `task' command.")
		end
	    end

	    # Returns the task which creates the last directory
	    # element (and has all other necessary directories as
	    # prerequisites).
	    def task(app, ch, name, prerequisites = [], &block)
		dirs = ::Rant::Sys.split_path(name)
		if dirs.empty?
		    app.abort(app.pos_text(ch[:file], ch[:ln]),
			"Not a valid directory name: `#{name}'")
		end
		ld = nil
		path = nil
		last_task = nil
		task_block = nil
		dirs.each { |dir|
		    pre = [ld]
		    pre.compact!
		    if dir.equal?(dirs.last)
			pre.concat prerequisites if prerequisites
			task_block = block
		    end
		    path = path.nil? ? dir : File.join(path, dir)
		    last_task = app.prepare_task({:__caller__ => ch,
			    path => pre}, task_block) { |name,pre,blk|
			self.new(app, name, pre, &blk)
		    }
		    ld = dir
		}
		last_task
	    end
	end

	def intialize *args
	    super
	    @ts = T0
	    @isdir = nil
	end

	def needed?
	    invoke(:needed? => true)
	end

	def invoke(opt = INVOKE_OPT)
	    return if done?
	    @isdir = test(?d, @name)
	    if @isdir
		@ts = @block ? test(?M, @name) : Time.now
		internal_invoke opt, false
	    else
		@ts = T0
		internal_invoke opt, true
	    end
	end

	def handle_filetask(dep, opt)
	    return @block if dep.invoke opt
	    if dep.path.exist?
		@block && dep.path.mtime > @ts
	    end
	end

	def handle_non_worker(dep, opt)
	    dep = Path.new(dep) unless Path === dep
	    unless dep.exist?
		err_msg @app.pos_text(rantfile.path, line_number),
		    "in prerequisites: no such file or task: `#{dep}'"
		self.fail
	    end
	    [dep, @block && dep.mtime > @ts]
	end

	def run
	    @app.sys.mkdir @name unless @isdir
	    if @block
		@block.arity == 0 ? @block.call : @block[self]
		@app.sys.touch @name
	    end
	end
    end	# class DirTask
    module Generators
	Directory = ::Rant::DirTask
    end
end # module Rant
