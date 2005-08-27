
# node.rb - Base of Rant nodes.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant

    class TaskFail < StandardError
	def initialize(task, orig, msg)
	    @task = task
	    @orig = orig
            @msg = msg
	end
        def exception
            self
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
        def msg
            @msg
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
        alias to_s path
        alias to_str path
    end	# class Rantfile

    # Any +object+ is considered a _task_ if
    # <tt>Rant::Node === object</tt> is true.
    #
    # Most important classes including this module are the Rant::Task
    # class and the Rant::FileTask class.
    module Node

	INVOKE_OPT = {}.freeze

	T0 = Time.at(0).freeze

	# Name of the task, this is always a string.
	attr_reader :name
	# A reference to the Rant compiler this task belongs to.
	attr_reader :rac
	# Description for this task.
	attr_accessor :description
	# The rantfile this task was defined in.
	# Should be a Rant::Rantfile instance.
	attr_accessor :rantfile
	# The linenumber in rantfile where this task was defined.
	attr_accessor :line_number
	# The directory in which this task was defined, relative to
	# the projects root directory.
        attr_accessor :project_subdir
	
	def initialize
	    @description = nil
	    @rantfile = nil
	    @line_number = nil
	    @run = false
            @project_subdir = ""
	end

        def reference_name
            sd = rac.current_subdir
            case sd
            when "": full_name
            when project_subdir: name
            else "@#{full_name}".sub(/^@#{Regexp.escape sd}\//, '')
            end
        end

        alias to_s reference_name
        alias to_rant_target name

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
	    @rac.goto_project_dir project_subdir
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
	# All objects implementing the Rant::Node protocol should
	# know about the following +opt+ values:
	# <tt>:needed?</tt>::
	#	Just check if this task is needed.  Should do the same
	#	as calling Node#needed?
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
            raise TaskFail.new(self, orig, msg)
	end

	# Change pwd to task home directory and yield for each created
	# file/directory.
	#
	# Override in subclasses if your task instances create files.
	def each_target
	end

        private
	def run
	    return unless @block
	    goto_task_home
            @rac.running_task(self)
	    @block.arity == 0 ? @block.call : @block[self]
	end

	def circular_dep
	    rac.warn_msg "Circular dependency on task `#{full_name}'."
	    false
	end
    end	# module Node
end # module Rant
