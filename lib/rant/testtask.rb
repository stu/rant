
require 'rant/rantlib'

module Rant
    class TestTask

	class << self

	    def gen_rant_task(app, clr, args, &block)
		if !args || args.empty?
		    self.new(app, clr, &block)
		elsif args.size == 1
		    name, pre, file, ln = app.normalize_task_arg(args.first, clr)
		    self.new(app, clr, name, pre, &block)
		else
		    app.abort(app.pos_text(file, ln),
			"TestTask takes only one additional argument, " +
			"which should be like one given to the `task' command.")
		end
	    end
	end

	attr_accessor :verbose
	attr_accessor :libs
	attr_accessor :options
	attr_accessor :test_dirs
	attr_accessor :pattern
	attr_accessor :test_files

	def initialize(app, clr, name = :test, prerequisites = [], &block)
	    @name = name
	    @pre = prerequisites
	    @block = block
	    @verbose = nil
	    cf = Lib.parse_caller_elem(clr)[:file]
	    @libs = []
	    libdir = File.join(File.dirname(
		File.expand_path(cf)), 'lib')
	    @libs << libdir if test(?d, libdir)
	    @options = []
	    @test_dirs = []
	    @pattern = nil
	    @test_files = nil
	    yield self if block_given?
	    if test(?d, "test")
		@test_dirs << "test" 
	    elsif test(?d, "tests")
		@test_dirs << "tests"
	    end
	    @pattern = "test*.rb" if @pattern.nil? && @test_files.nil?

	    @pre ||= []
	    # define the task
	    app.task({:__caller__ => clr, @name => @pre}) { |t|
		arg = ""
		libpath = (@libs.nil? || @libs.empty?) ?
		    nil : @libs.join(File::PATH_SEPARATOR)
		if libpath
		    arg << "-I " << Env.shell_path(libpath) << " "
		end
		arg << "-S testrb " << filelist.arglist
		arg << optlist
		ruby arg
	    }
	end
	def optlist
	    options = (@options.is_a? Array) ?
		@options.arglist : @options 
	    ENV["TESTOPTS"] || options || ""
	end
	def filelist
	    return Dir[ENV['TEST']] if ENV['TEST']
	    filelist = @test_files || []
	    if filelist.empty?
		if @test_dirs && !@test_dirs.empty?
		    @test_dirs.each { |dir|
			filelist.concat(Dir[File.join(dir, @pattern)])
		    }
		else
		    filelist.concat(Dir[@pattern])
		end
	    end
	    filelist
	end
    end
end
