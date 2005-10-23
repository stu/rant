
# default.rb - Default node types for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant

    def self.init_import_nodes__default(rac, *rest)
        rac.node_factory = DefaultNodeFactory.new
    end

    class DefaultNodeFactory
        def new_task(rac, name, pre, blk)
            Task.new(rac, name, pre, &blk)
        end
        def new_file(rac, name, pre, blk)
            FileTask.new(rac, name, pre, &blk)
        end
        def new_dir(rac, name, pre, blk)
            DirTask.new(rac, name, pre, &blk)
        end
        def new_source(rac, name, pre, blk)
            SourceNode.new(rac, name, pre, &blk)
        end
        def new_custom(rac, name, pre, blk)
            UserTask.new(rac, name, pre, &blk)
        end
        def new_auto_subfile(rac, name, pre, blk)
            AutoSubFileTask.new(rac, name, pre, &blk)
        end
    end

    class Task
	include Node

        attr_accessor :receiver

	def initialize(rac, name, prerequisites = [], &block)
	    super()
	    @rac = rac or raise ArgumentError, "rac not given"
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
            @receiver = nil
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
            @block or @receiver && @receiver.has_pre_action?
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

	def internal_invoke(opt, ud_init = true)
	    goto_task_home
	    update = ud_init || opt[:force]
	    dep = nil
	    uf = false
	    each_dep { |dep|
		if dep.respond_to? :timestamp
		    handle_timestamped(dep, opt) && update = true
		elsif Node === dep
		    handle_node(dep, opt) && update = true
		else
		    dep, uf = handle_non_node(dep, opt)
		    uf && update = true
		    dep
		end
	    }
            if @receiver
                goto_task_home
                update = true if @receiver.update?(self)
            end
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
	# is_a? Node, but not a FileTask. +opt+ are opts as given to
	# Node#invoke.
	#
	# Override this method in subclasses to modify behaviour of
	# prerequisite handling.
	#
	# See also: handle_timestamped, handle_non_node
	def handle_node(dep, opt)
	    dep.invoke opt
	end

	# Called from internal_invoke. +dep+ is a prerequisite which
	# is_a? FileTask. +opt+ are opts as given to Node#invoke.
	#
	# Override this method in subclasses to modify behaviour of
	# prerequisite handling.
	#
	# See also: handle_node, handle_non_node
	def handle_timestamped(dep, opt)
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
	# See also: handle_node, handle_timestamped
	def handle_non_node(dep, opt)
	    @rac.err_msg "Unknown task `#{dep}',",
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
		if Node === t
		    # Remove references to self from prerequisites!
		    if t.full_name == my_full_name
			nil
		    else
			yield(t)
			t
		    end
		else
		    t = t.to_s if Symbol === t
		    if t == my_full_name #TODO
			nil
		    else
			#STDERR.puts "selecting `#{t}'"
			selection = @rac.resolve t,
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

	def initialize(*args)
	    super
	    # super will set @block to a given block, but the block is
	    # used for initialization, not ment as action
	    @block = nil
	    @needed = nil
            @target_files = nil
	    # allow setting of @block and @needed
	    yield self if block_given?
	end

	def act(&block)
	    @block = block
	end

	def needed(&block)
	    @needed = block
	end

        def file_target?
            @target_files and @target_files.include? @name
        end

        def each_target(&block)
            goto_task_home
            @target_files.each(&block) if @target_files
        end
        
        def file_target(*args)
            args.flatten!
            args << @name if args.empty?
            if @target_files
                @target_files.concat(args)
            else
                @target_files = args
            end
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

	def initialize(*args)
	    super
	    @ts = T0
	end

        def file_target?
            true
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

	def timestamp(opt = INVOKE_OPT)
	    File.exist?(@name) ? File.mtime(@name) : T0
	end

        def handle_node(dep, opt)
            #STDERR.puts "treating #{dep.full_name} as file dependency"
            return true if dep.file_target? && dep.invoke(opt)
	    if File.exist? dep.name
                File.mtime(dep.name) > @ts
            elsif !dep.file_target?
		@rac.err_msg @rac.pos_text(rantfile.path, line_number),
		    "in prerequisites: no such file: `#{dep.full_name}'"
		self.fail
	    end
        end

	def handle_timestamped(dep, opt)
	    return true if dep.invoke opt
	    #puts "***`#{dep.name}' requires update" if dep.timestamp > @ts
	    dep.timestamp(opt) > @ts
	end

	def handle_non_node(dep, opt)
            goto_task_home # !!??
	    unless File.exist? dep
		@rac.err_msg @rac.pos_text(rantfile.path, line_number),
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

    module AutoInvokeDirNode
	private
	def run
            goto_task_home
            @rac.running_task(self)
	    dir = File.dirname(name)
            @rac.build dir unless dir == "." || dir == "/"
            return unless @block
            @block.arity == 0 ? @block.call : @block[self]
	end
    end

    class AutoSubFileTask < FileTask
        include AutoInvokeDirNode
    end

    # An instance of this class is a task to create a _single_
    # directory.
    class DirTask < Task

	def initialize(*args)
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

        def file_target?
            true
        end

        def handle_node(dep, opt)
            #STDERR.puts "treating #{dep.full_name} as file dependency"
            return true if dep.file_target? && dep.invoke(opt)
	    if File.exist? dep.name
                File.mtime(dep.name) > @ts
            elsif !dep.file_target?
		@rac.err_msg @rac.pos_text(rantfile.path, line_number),
		    "in prerequisites: no such file: `#{dep.full_name}'"
		self.fail
	    end
        end

	def handle_timestamped(dep, opt)
	    return @block if dep.invoke opt
	    @block && dep.timestamp(opt) > @ts
	end

	def handle_non_node(dep, opt)
            goto_task_home
	    unless File.exist? dep
		@rac.err_msg @rac.pos_text(rantfile.path, line_number),
		    "in prerequisites: no such file or task: `#{dep}'"
		self.fail
	    end
	    [dep, @block && File.mtime(dep) > @ts]
	end

	def run
            @rac.running_task(self)
	    @rac.sys.mkdir @name unless @isdir
	    if @block
		@block.arity == 0 ? @block.call : @block[self]
		goto_task_home
		@rac.sys.touch @name
	    end
	end

	def each_target
	    goto_task_home
	    yield name
	end
    end	# class DirTask

    # A SourceNode describes dependencies between source files. Thus
    # there is no action attached to a SourceNode. The target should
    # be an existing file as well as all dependencies.
    #
    # An example would be a C source file which depends on other C
    # source files because of <tt>#include</tt> statements.
    #
    # Rantfile usage:
    #	gen SourceNode, "myext.c" => %w(ruby.h myext.h)
    class SourceNode
	include Node
	def initialize(rac, name, prerequisites = [])
	    super()
	    @rac = rac
	    @name = name or raise ArgumentError, "name not given"
	    @pre = prerequisites
	    @run = false
	    # The timestamp is the latest of this file and all
	    # dependencies:
	    @ts = nil
	end
	# Use this readonly!
	def prerequisites
	    @pre
	end
	# Note: The timestamp will only be calculated once!
	def timestamp(opt = INVOKE_OPT)
	    # Circular dependencies don't generate endless
	    # recursion/loops because before calling the timestamp
	    # method of any other node, we set @ts to some non-nil
	    # value.
	    return @ts if @ts
	    goto_task_home
	    if File.exist?(@name)
		@ts = File.mtime @name
	    else
		rac.abort(rac.pos_text(@rantfile, @line_number),
		    "SourceNode: no such file -- #@name")
	    end
	    sd = project_subdir
	    @pre.each { |f|
		nodes = rac.resolve f, sd
		if nodes.empty?
		    if File.exist? f
			mtime = File.mtime f
			@ts = mtime if mtime > @ts
		    else
			rac.abort(rac.pos_text(@rantfile, @line_number),
			    "SourceNode: no such file -- #{f}")
		    end
		else
		    nodes.each { |node|
                        node.invoke(opt)
			if node.respond_to? :timestamp
			    node_ts = node.timestamp(opt)
                            goto_task_home
			    @ts = node_ts if node_ts > @ts
			else
			    rac.abort(rac.pos_text(@rantfile, @line_number),
				"SourceNode can't depend on #{node.name}")
			end
		    }
		end
	    }
	    @ts
	end
	def needed?
	    false
	end
	def invoke(opt = INVOKE_OPT)
	    false
	end
        def related_sources
            @pre
        end
    end # class SourceNode
end # module Rant
