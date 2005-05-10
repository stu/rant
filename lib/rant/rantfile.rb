
# rantfile.rb - Define task core for rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantenv'

module Rant
    class TaskFail < StandardError
	def initialize(*args)
	    @task = args.shift
	    #super(args.shift)
	    @orig = args.shift
	end
	def task
	    @task
	end
	def tname
	    @task ? @task.name : nil
	end
	# the exception which caused the task to fail
	def orig
	    @orig
	end
    end

    class Rantfile

	attr_reader :tasks, :path
	attr_accessor :project_subdir
	
	def initialize(path)
	    @path = path or raise ArgumentError, "path required"
	    @tasks = []
	    @project_subdir = nil
	end
	def to_s
	    @path
	end
    end	# class Rantfile

    # Any +object+ is considered a _task_ if
    # <tt>Rant::Worker === object</tt> is true.
    #
    # Most important classes including this module are the Rant::Task
    # class and the Rant::FileTask class.
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
	    @run = false
	end

	# Returns the full name of this task.
	def to_s
	    full_name
	end

	# The directory in which this task was defined, relative to
	# the projects root directory.
	def project_subdir
	    @rantfile.nil? ? "" : @rantfile.project_subdir
	end

	# Basically project_subdir/name
	#
	# The Rant compiler (or application) references tasks by their
	# full_name.
	def full_name
	    sd = project_subdir
	    sd.empty? ? name : File.join(sd, name)
	end

	# Change current working directory to the directory this task
	# was defined in.
	#
	# Important for subclasses: Call this method always before
	# invoking code from Rantfiles (e.g. task action blocks).
	def goto_task_home
	    @app.goto_project_dir project_subdir
	end

	def done?
	    @done
	end

	def needed?
	    !done?
	end

	# True during invoke. Used to encounter circular dependencies.
	def run?
	    @run
	end

	# +opt+ is a Hash and shouldn't be modified.
	# All objects implementing the Rant::Worker protocol should
	# know about the following +opt+ values:
	# <tt>:needed?</tt>::
	#	Just check if this task is needed.  Should do the same
	#	as calling Worker#needed?
	# <tt>:force</tt>::
	#	Run task action even if needed? is false.
	# Returns true if task action was run.
	def invoke(opt = INVOKE_OPT)
	    return circular_dep if run?
	    @run = true
	    begin
		return needed? if opt[:needed?]
		self.run if opt[:force] || self.needed?
	    ensure
		@run = false
	    end
	end

	# Cause task to fail. Usually called from inside the block
	# given to +act+.
	def fail msg = nil, orig = nil
	    raise TaskFail.new(self, orig), msg, caller
	end

	# Change pwd to task home directory and yield for each created
	# file/directory.
	#
	# Override in subclasses if your task instances create files.
	def each_target
	end

	def run
	    return unless @block
	    goto_task_home
	    @block.arity == 0 ? @block.call : @block[self]
	end
	private :run

	def circular_dep
	    app.warn_msg "Circular dependency on task `#{full_name}'."
	    false
	end
	private :circular_dep

	# Tasks are hashed by their full_name.
	def hash
	    full_name.hash
	end

	def eql? other
	    Worker === other and full_name.eql? other.full_name
	end
    end	# module Worker

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
		    self.new(app, name, &blk)
		}
	    end
	end

	def initialize(app, name)
	    super()
	    @app = app or raise ArgumentError, "no app given"
	    @name = name
	    @needed = nil
	    @block = nil
	    @done = false
	    yield self if block_given?
	end

	def app
	    @app
	end

	def needed &block
	    @needed = block
	end

	def act &block
	    @block = block
	end

	def needed?
	    return false if done?
	    return true if @needed.nil?
	    goto_task_home
	    @needed.arity == 0 ? @needed.call : @needed[self]
	end

	def invoke(opt = INVOKE_OPT)
	    return circular_dep if @run
	    @run = true
	    begin
		return needed? if opt[:needed?]
		# +run+ already calls +goto_task_home+
		#goto_task_home
		if opt[:force] && !@done or needed?
		    run
		    @done = true
		end
	    rescue CommandError => e
		err_msg e.message if app[:err_commands]
		self.fail(nil, e)
	    rescue SystemCallError => e
		err_msg e.message
		self.fail(nil, e)
	    ensure
		@run = false
	    end
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
	    @app = app || Rant.rac
	    @name = name or raise ArgumentError, "name not given"
	    @pre = prerequisites || []
	    @pre_resolved = false
	    @block = block
	    @run = false
	    # success has one of three values:
	    #	nil	no invoke
	    #	false	invoked, but fail
	    #	true	invoked and run successfully
	    @success = nil
	end

	# Get a list of the *names* of all prerequisites. The
	# underlying list of prerequisites can't be modified by the
	# value returned by this method.
	def prerequisites
	    @pre.collect { |pre| pre.to_s }
	end
	alias deps prerequisites

	# First prerequisite.
	def source
	    @pre.first.to_s
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

	# Was this task ever invoked? If this is true, it doesn't
	# necessarily mean that the run was successfull!
	def invoked?
	    !@success.nil?
	end

	# True if last task run fail.
	def fail?
	    @success == false
	end

	# Task was run and didn't fail.
	def done?
	    @success
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
	    return circular_dep if @run
	    @run = true
	    begin
		return if done?
		internal_invoke opt
	    ensure
		@run = false
	    end
	end

	def internal_invoke opt, ud_init = true
	    goto_task_home
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
	    run if update
	    @success = true
	    # IMPORTANT: return update flag
	    update
	rescue StandardError => e
	    @success = false
	    self.fail(nil, e)
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
	    my_full_name = full_name
	    my_project_subdir = project_subdir
	    @pre.map! { |t|
		if Worker === t
		    # Remove references to self from prerequisites!
		    if t.full_name == my_full_name
			nil
		    else
			yield(t)
			t
		    end
		else
		    t = t.to_s if Symbol === t
		    if t == my_full_name
			nil
		    else
			#STDERR.puts "selecting `#{t}'"
			selection = @app.resolve t,
					my_project_subdir
			#STDERR.puts selection.size
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
	    return circular_dep if @run
	    @run = true
	    begin
		return if done?
		internal_invoke(opt, ud_init_by_needed)
	    ensure
		@run = false
	    end
	end

	private
	def ud_init_by_needed
	    if @needed
		goto_task_home
		@needed.arity == 0 ? @needed.call : @needed[self]
	    #else: true #??
	    end
	end
    end	# class UserTask

    class FileTask < Task

	def initialize *args
	    super
	    @ts = T0
	end

	# TODO: remove this method?
	def path
	    @name
	end

	def needed?
	    return false if done?
	    invoke(:needed? => true)
	end

	def invoke(opt = INVOKE_OPT)
	    return circular_dep if @run
	    @run = true
	    begin
		return if done?
		goto_task_home
		if File.exist? @name
		    @ts = File.mtime @name
		    internal_invoke opt, false
		else
		    @ts = T0
		    internal_invoke opt, true
		end
	    ensure
		@run = false
	    end
	end

	def handle_filetask(dep, opt)
	    return true if dep.invoke opt
	    if File.exist?(dep.name)
		#puts "***`#{dep.name}' requires update" if dep.path.mtime > @ts
		File.mtime(dep.name) > @ts
	    end
	end

	def handle_non_worker(dep, opt)
	    unless File.exist? dep
		err_msg @app.pos_text(rantfile.path, line_number),
		    "in prerequisites: no such file or task: `#{dep}'"
		self.fail
	    end
	    [dep, File.mtime(dep) > @ts]
	end

	def each_target
	    goto_task_home
	    yield name
	end
    end	# class FileTask

    class AutoSubFileTask < FileTask
	private
	def run
	    dir, = File.split(name)
	    unless dir == "."
		dt = @app.resolve(dir, project_subdir).last
		dt.invoke if DirTask === dt
	    end
	    super
	end
    end	# class AutoSubFileTask

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
		case args.size
		when 1
		    name, pre, file, ln = app.normalize_task_arg(args.first, ch)
		    self.task(app, ch, name, pre, &block)
		when 2
		    basedir = args.shift
		    if basedir.respond_to? :to_str
			basedir = basedir.to_str
		    else
			app.abort_at(ch,
			    "Directory: basedir argument has to be a string.")
		    end
		    name, pre, file, ln = app.normalize_task_arg(args.first, ch)
		    self.task(app, ch, name, pre, basedir, &block)
		else
		    app.abort(app.pos_text(ch[:file], ch[:ln]),
			"Directory takes one argument, " +
			"which should be like one given to the `task' command.")
		end
	    end

	    # Returns the task which creates the last directory
	    # element (and has all other necessary directories as
	    # prerequisites).
	    def task(app, ch, name, prerequisites=[], basedir=nil, &block)
		dirs = ::Rant::Sys.split_path(name)
		if dirs.empty?
		    app.abort_at(ch,
			"Not a valid directory name: `#{name}'")
		end
		path = basedir
		last_task = nil
		task_block = nil
		desc_for_last = app.pop_desc
		dirs.each { |dir|
		    pre = [path]
		    pre.compact!
		    if dir.equal?(dirs.last)
			app.cx.desc desc_for_last
			pre.concat prerequisites if prerequisites
			task_block = block
		    end
		    path = path.nil? ? dir : File.join(path, dir)
		    last_task = app.prepare_task({:__caller__ => ch,
			    path => pre}, task_block) { |name,pre,blk|
			self.new(app, name, pre, &blk)
		    }
		}
		last_task
	    end
	end

	def initialize *args
	    super
	    @ts = T0
	    @isdir = nil
	end

	def invoke(opt = INVOKE_OPT)
	    return circular_dep if @run
	    @run = true
	    begin
		return if done?
		goto_task_home
		@isdir = test(?d, @name)
		if @isdir
		    @ts = @block ? test(?M, @name) : Time.now
		    internal_invoke opt, false
		else
		    @ts = T0
		    internal_invoke opt, true
		end
	    ensure
		@run = false
	    end
	end

	def handle_filetask(dep, opt)
	    return @block if dep.invoke opt
	    if File.exist?(dep.name)
		@block && File.mtime(dep.name) > @ts
	    end
	end

	def handle_non_worker(dep, opt)
	    unless File.exist? dep
		err_msg @app.pos_text(rantfile.path, line_number),
		    "in prerequisites: no such file or task: `#{dep}'"
		self.fail
	    end
	    [dep, @block && File.mtime(dep) > @ts]
	end

	def run
	    @app.sys.mkdir @name unless @isdir
	    if @block
		@block.arity == 0 ? @block.call : @block[self]
		goto_task_home
		@app.sys.touch @name
	    end
	end

	def each_target
	    goto_task_home
	    yield name
	end
    end	# class DirTask
    module Generators
	Task = ::Rant::Task
	LightTask = ::Rant::LightTask
	Directory = ::Rant::DirTask

	class Rule < ::Proc
	    # Generate a rule by installing an at_resolve hook for
	    # +rac+.
	    def self.rant_generate(rac, ch, args, &block)
		unless args.size == 1
		    rac.abort_at(ch, "Rule takes only one argument.")
		end
		arg = args.first
		target = nil
		src_arg = nil
		if Symbol === arg
		    target = ".#{arg}"
		elsif arg.respond_to? :to_str
		    target = arg.to_str
		elsif Regexp === arg
		    target = arg
		elsif Hash === arg && arg.size == 1
		    arg.each_pair { |target, src_arg| }
		    src_arg = src_arg.to_str if src_arg.respond_to? :to_str
		    target = target.to_str if target.respond_to? :to_str
		    src_arg = ".#{src_arg}" if Symbol === src_arg
		    target = ".#{target}" if Symbol === target
		else
		    rac.abort_at(ch, "Rule argument " +
			"has to be a hash with one key-value pair.")
		end
		esc_target = nil
		target_rx = case target
		when String
		    esc_target = Regexp.escape(target)
		    /#{esc_target}$/
		when Regexp
		    target
		else
		    rac.abort_at(ch, "rule target has " +
			"to be a string or regular expression")
		end
		src_proc = case src_arg
		when String
		    unless String === target
			rac.abort(ch, "rule target has to be a string " +
			    "if source is a string")
		    end
		    lambda { |name| name.sub(/#{esc_target}$/, src_arg) }
		when Proc: src_arg
		when nil: lambda { |name| [] }
		else
		    rac.abort_at(ch, "rule source has to be " +
			"String or Proc")
		end
		blk = self.new { |task_name|
		    if target_rx =~ task_name
			[rac.file(:__caller__ => ch,
			    task_name => src_proc[task_name], &block)]
		    else
			nil
		    end
		}
		blk.target_rx = target_rx
		rac.at_resolve(&blk)
		nil
	    end
	    attr_accessor :target_rx
	end	# class Rule

	class Action
	    def self.rant_generate(rac, ch, args, &block)
		unless args.empty?
		    rac.warn_msg(rac.pos_text(ch[:file], ch[:ln]),
			"Action doesn't take arguments.")
		end
		unless (rac[:tasks] || rac[:stop_after_load])
		    yield
		end
	    end
	end
    end	# module Generators
end # module Rant
