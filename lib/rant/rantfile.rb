
require 'rant/rantenv'

class Rant::TaskFail < StandardError
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

class Rant::Rantfile < Rant::Path

    attr_reader :tasks
    
    def initialize(*args)
	super
	@tasks = []
    end
end	# class Rant::Rantfile

class Rant::Task
    include Rant::Console

    # Name of the task, this is always a string.
    attr_reader :name
    # A description for this task.
    attr_accessor :description
    # A reference to the application this task belongs to.
    attr_reader :app
    # The rantfile this task was defined in.
    # Should be a Rant::Rantfile instance.
    attr_accessor :rantfile
    # The linenumber in rantfile where this task was defined.
    attr_accessor :line_number
    
    def initialize(app, name, prerequisites = [], &block)
	@app = app || Rant.rantapp
	@name = name or raise ArgumentError, "name not given"
	@description = nil
	@pre = prerequisites || []
	@pre_resolved = false
	@block = block
	@run = false
	@fail = false
	@rantfile = nil
	@line_number = 0
    end

    # Get a list of the *names* of all prerequisites. The underlying
    # list of prerequisites can't be modified by the value returned by
    # this method.
    def prerequisites
	@pre.collect { |pre|
	    if pre.is_a? String
		pre
	    elsif pre.is_a? ::Rant::Task
		pre.name
	    else
		pre.to_s
	    end
	}
    end

    # True if this task has at least one action (block to be executed)
    # associated.
    def has_actions?
	!!@block
    end

    # Add a prerequisite.
    def <<(pre)
	@pre_resolved = false
	@pre << pre
    end

    # Cause task to fail. Equivalent to calling Task.fail.
    def fail msg = nil
	raise Rant::TaskFail.new(self), msg, caller
    end

    # Was this task ever run? If this is true, it doesn't necessarily
    # mean that the run was successfull!
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

    def needed?
	# TODO: optimize
	done? or return true
	resolve_tasks
	each_task { |t| return true if t.needed? }
	false
    end

    # Enhance this task with the given dependencies and blk.
    def enhance(deps = [], &blk)
	@pre.concat deps if deps
	if blk
	    first_block = @block
	    @block = lambda { |t|
		first_block[t]
		blk[t]
	    }
	end
    end

    # Unconditionally run this tasks. All dependencies will be
    # run if necessary.
    # Raises a Rant::TaskFail exception on failure.
    def run
	@run = true
	resolve_prerequisites
	ensure_tasks
	if @block
	    @fail = true
	    begin
		# A task run is considered as failed, if the called
		# block raises an exception.
		if @block.arity == 0
		    @block.call
		else
		    @block[self]
		end
		@fail = false
	    rescue ::Rant::TaskFail => e
		m = e.message
		err_msg m if m && m != "Rant::TaskFail"
	    rescue ::Rant::CommandError => e
		err_msg e.message
	    rescue SystemCallError => e
		err_msg e.message
	    rescue
		err_msg $!.message, $!.backtrace
	    end
	    if @fail
		self.fail
	    end
	end
    end

    # Run each needed task prerequisite.
    def ensure_tasks
	each_task { |t| t.run if t.needed?  }
    rescue Rant::TaskFail
	@fail = true
	raise
    end

    # Resolve all prerequisites which aren't already Rant::Task
    # instances.
    def resolve_prerequisites
	resolve_tasks
	each_non_task { |t|
	    err_msg "Unknown task `#{t.to_s}',",
		"referenced in `#{rantfile.path}', line #{@line_number}!"
	    raise Rant::TaskFail, @name.to_s
	}
    end

    def resolve_tasks
	# TODO: optimize
	@pre.map! { |t|
	    if t.is_a? Rant::Task
		# Remove references to self from prerequisites!
		t.name == @name ? nil : t
	    else
		t = t.to_s if t.is_a? Symbol
		if t == @name
		    nil
		else
		    # Take care: selection is an array of tasks
		    selection = @app.select_tasks { |st| st.name == t }
		    selection.empty? ? t : selection
		end
	    end
	}
	@pre.flatten!
	@pre.compact!
    end

    ####### experimental #############################################
    # Returns a true value if task was acutally run.
    # Raises Rant::TaskFail to signal task (or prerequiste) failure.
    def invoke(force = true)
	return if done? && !force
	internal_invoke(true)
    end
    def internal_invoke force
	update = force
	dep = nil
	uf = false
	each_dep { |dep|
	    if Rant::Task === dep
		dep.invoke && update = true
	    else
		dep, uf = handle_non_task(dep)
		uf && update = true
		dep
	    end
	}
	if update
	    @run = true
	    if @block
		@block.arity == 0 ? @block.call : @block[self]
	    end
	end
	@run
    rescue StandardError => e
	@fail = true
	case e
	when Rant::TaskFail: raise
	when Rant::CommandError
	    err_msg e.message
	when SystemCallError
	    err_msg e.message
	else
	    err_msg e.message, e.backtrace
	end
	self.fail
    end
    private :internal_invoke
    # Override in subclass if specific task can handle
    # non-task-prerequisites.
    #
    # Notes for overriding:
    # This method should do one of the two following:
    # [1] Fail with an exception.
    # [2] Return two values: replacement_for_dep, update_required
    def handle_non_task(dep)
	err_msg "Unknown task `#{dep}',",
	    "referenced in `#{rantfile.path}', line #{@line_number}!"
	self.fail
    end
    # For each non-task prerequiste, the value returned from yield
    # will replace the original prerequisite (of course only if
    # @pre_resolved is false).
    def each_dep
	t = nil
	if @pre_resolved
	    return @pre.each { |t| yield(t) }
	end
	@pre.map! { |t|
	    if t.is_a? Rant::Task
		# Remove references to self from prerequisites!
		t.name == @name ? nil : yield(t)
		if t.name == @name
		    nil
		else
		    yield(t)
		    t
		end
	    else
		t = t.to_s if t.is_a? Symbol
		if t == @name
		    nil
		else
		    # Take care: selection is an array of tasks
		    selection = @app.select_tasks { |st| st.name == t }
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
    ##################################################################

    # Yield for each Rant::Task in prerequisites.
    def each_task
	@pre.each { |t|
	    yield(t) if t.is_a? Rant::Task
	}
    end

    # Yield for each element which isn't an Rant::Task instance in
    # prerequisites.
    def each_non_task
	@pre.each { |t|
	    yield(t) unless t.is_a? Rant::Task
	}
    end

    def hash
	@name.hash
    end

    def eql? other
	Rant::Task === other and @name.eql? other.name
    end
end	# class Rant::Task

class Rant::FileTask < Rant::Task

    T0 = Time.at 0

    def initialize *args
	super
	if @name.is_a? Rant::Path
	    @path = @name
	    @name = @path.to_s
	else
	    @path = Rant::Path.new @name
	end
	@ts = T0
    end
    def path
	@path
    end
    def needed?
	return true unless @path.exist?
	resolve_prerequisites
	each_task { |t|
	    return true if t.needed?
	}
	ts = @path.mtime
	each_non_task { |ft|
	    return true if ft.mtime > ts
	}
	false
    end
    def resolve_prerequisites
	resolve_tasks
	resolve_pathes
    end
    def resolve_pathes
	@pre.map! { |t|
	    unless t.is_a? Rant::Task
		t = Rant::Path.new(t) unless t.is_a? Rant::Path
		unless t.exist?
		    @fail = true
		    err_msg "No such file `#{t.to_s}',",
			"referenced in `#{rantfile.path}'"
		    raise Rant::TaskFail, @name.to_s
		end
	    end
	    t
	}
    end

    ####### experimental #############################################
    def invoke(force = false)
	return if done? && !force
	if @path.exist?
	    @ts = @path.mtime
	    internal_invoke(force)
	else
	    @ts = T0
	    internal_invoke(true)
	end
    end
    def handle_non_task(dep)
	dep = Rant::Path.new(dep) unless Rant::Path === dep
	unless dep.exist?
	    err_msg @app.pos_text(rantfile.path, line_number),
		"in prerequisites: no such file or task: `#{dep}'"
	    self.fail
	end
	[dep, dep.mtime > @ts]
    end
    ##################################################################
end	# class Rant::FileTask
