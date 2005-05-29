
require 'rant/rantlib'

module Rant
    class Generators::RubyTest

	class << self

	    def rant_gen(app, ch, args, &block)
		if !args || args.empty?
		    self.new(app, ch, &block)
		elsif args.size == 1
		    name, pre, file, ln =
		    app.normalize_task_arg(args.first, ch)
		    self.new(app, ch, name, pre, &block)
		else
		    app.abort(app.pos_text(file, ln),
			"RubyTest takes only one additional argument, " +
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
	# Directory where to run unit tests.
	attr_accessor :test_dir

	def initialize(app, cinf, name = :test, prerequisites = [], &block)
	    @rac = app
	    @name = name
	    @pre = prerequisites
	    @block = block
	    @verbose = nil
	    cf = cinf[:file]
	    @libs = []
	    libdir = File.join(File.dirname(
		File.expand_path(cf)), 'lib')
	    @libs << libdir if test(?d, libdir)
	    @options = []
	    @test_dirs = []
	    @pattern = nil
	    @test_files = nil
	    @test_dir = nil
	    yield self if block_given?
	    @pattern = "test*.rb" if @pattern.nil? && @test_files.nil?

	    @pre ||= []
	    # define the task
	    app.task({:__caller__ => cinf, @name => @pre}) { |t|
		arg = ""
		libpath = (@libs.nil? || @libs.empty?) ?
		    nil : @libs.join(File::PATH_SEPARATOR)
		if libpath
		    arg << "-I " << Env.shell_path(libpath) << " "
		end
		arg << "-S testrb " << optlist
		if @test_dir
		    app.context.sys.cd(@test_dir) {
			arg << filelist.arglist
			app.context.sys.ruby arg
		    }
		else
		    if test(?d, "test")
			@test_dirs << "test" 
		    elsif test(?d, "tests")
			@test_dirs << "tests"
		    end
		    arg << filelist.arglist
		    app.context.sys.ruby arg
		end
	    }
	end
	def optlist
	    options = (@options.is_a? Array) ?
		@options.arglist : @options 
	    @rac.cx.var["TESTOPTS"] || options || ""
	end
	def filelist
	    return Dir[@rac.cx.var['TEST']] if @rac.cx.var['TEST']
	    filelist = @test_files || []
	    if filelist.empty?
		if @test_dirs && !@test_dirs.empty?
		    @test_dirs.each { |dir|
			filelist.concat(Dir[File.join(dir, @pattern)])
		    }
		else
		    filelist.concat(Dir[@pattern]) if @pattern
		end
	    end
	    filelist
	end
    end	# class Generators::RubyTest
end	# module Rant
