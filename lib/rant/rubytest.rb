
require 'rant/rantlib'

module Rant
    class Generators::RubyTest

	class << self

	    def rant_generate(app, ch, args, &block)
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

	def initialize(app, cinf, name = :test, prerequisites = [], &block)
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
	    yield self if block_given?
	    if test(?d, "test")
		@test_dirs << "test" 
	    elsif test(?d, "tests")
		@test_dirs << "tests"
	    end
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
		arg << "-S testrb " << filelist.arglist
		arg << optlist
		app.context.instance_eval { sys.ruby arg }
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
    end	# class Generators::RubyTest
end	# module Rant
