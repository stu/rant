
class Rant::TaskFail < StandardError
end

class Rant::Rantfile
    attr_reader :path
    attr_reader :tasks
    
    def initialize(path)
	@path = path or raise ArgumentError, "path not given"
	@tasks = []
    end
end	# class Rant::Rantfile

class Rant::Task
    include Rant::Console
    
    # This is the only state held by this class.
    @@all = {}

    class << self
	def all
	    @@all
	end
	
	def [](task_name)
	    @@all[task_name]
	end
    end

    attr_reader :name
    attr_accessor :rantfile
    attr_accessor :line_number
    
    def initialize(name, prerequisites = [], &block)
	@name = name or raise ArgumentError, "name not given"
	@pre = prerequisites || []
	@block = block
	@ran = false
	@fail = false
	@rantfile = nil
	@line_number = 0

	@@all[@name] = self
    end

    def prerequisites
	@pre
    end

    def ran?
	@ran
    end

    def fail?
	@fail
    end

    def done?
	ran? && !fail?
    end

    def needed?
	resolve_tasks
	each_task { |t| return true if t.needed? }
	!done?
    end

    # Raises a Rant::TaskFail exception on failure.
    def run
	@ran = true
	resolve_prerequisites
	ensure_tasks
	if @block
	    begin
		@fail = !@block[self]
	    rescue
		@fail = true
		err_msg $!.message
	    end
	    if @fail
		raise Rant::TaskFail, @name.to_s
	    end
	end
    end

    def ensure_tasks
	each_task { |t| t.run if t.needed?  }
    rescue Rant::TaskFail
	@fail = true
	raise
    end

    def resolve_prerequisites
	resolve_tasks
	each_non_task { |t|
	    err_msg "Unknown task `#{t.to_s}',",
		"referenced in `#{rantfile.path}'!"
	    raise Rant::TaskFail, @name.to_s
	}
    end

    def resolve_tasks
	@pre.map! { |t|
	    if t.is_a? Rant::Task
		t
	    else
		t = t.to_s if t.is_a? Symbol
		self.class[t] || t
	    end
	}
    end

    def each_task
	@pre.each { |t|
	    yield(t) if t.is_a? Rant::Task
	}
    end

    def each_non_task
	@pre.each { |t|
	    yield(t) unless t.is_a? Rant::Task
	}
    end

    def hash
	@name.hash
    end

    def eql? other
	self.hash == other.hash
    end
end	# class Rant::Task

class Rant::FileTask < Rant::Task
    def initialize *args
	super
	unless @name.is_a? Rant::Path
	    @name = Rant::Path.new @name
	end
    end
    def needed?
	return true if super
	resolve_pathes
	ts = @name.mtime
	each_non_task { |path|
	    return true if t.mtime > ts
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
end	# class Rant::FileTask
