
require 'rant/rantlib'

module Rant
    class Generators::RubyTest
        def self.rant_gen(app, ch, args, &block)
            if !args || args.empty?
                self.new(app, ch, &block)
            elsif args.size == 1
                name, pre = app.normalize_task_arg(args.first, ch)
                self.new(app, ch, name, pre, &block)
            else
                app.abort_at(ch,
                    "RubyTest takes only one additional argument, " +
                    "which should be like one given to the `task' command.")
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
        # How to load tests. Possible values:
        # [:rant]       Use Rant's loading mechanism. This is default.
        # [:testrb]     Use the testrb script which comes with Ruby
        #               1.8.1 and newer installations.
        attr_accessor :loader

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
            #@loader = RUBY_VERSION < "1.8.4" ? :testrb : :rant
            @loader = :rant
	    yield self if block_given?
	    @pattern = "test*.rb" if @pattern.nil? && @test_files.nil?

	    @pre ||= []
	    # define the task
	    app.task(:__caller__ => cinf, @name => @pre) { |t|
		args = []
                if @libs && !@libs.empty?
                    args << "-I#{@libs.join File::PATH_SEPARATOR}"
                end
                case @loader
                when :rant:
                    script = rb_testloader_path
                    if script
                        args << script
                    else
                        args << "-S" << "testrb"
                        app.warn_msg("Rant's test loader not found. " +
                            "Using `testrb'.")
                    end
                when :testrb: args << "-S" << "testrb"
                else
                    @rac.abort_at(cinf,
                        "RubyTest: No such test loader -- #@loader")
                end
                args.concat optlist
		if @test_dir
		    app.sys.cd(@test_dir) {
			args.concat filelist
			app.sys.ruby args
		    }
		else
		    if test(?d, "test")
			@test_dirs << "test" 
		    elsif test(?d, "tests")
			@test_dirs << "tests"
		    end
		    args.concat filelist
		    app.context.sys.ruby args
		end
	    }
	end
	def optlist
            if @options.respond_to? :to_ary
                @options.to_ary
            elsif @options
                [@options.to_str]
            else
                []
            end
            # previously Rant (0.4.4 and earlier versions) honoured
            # var["TESTOPTS"]
	end
	def filelist
	    return @rac.sys[@rac.var['TEST']] if @rac.var['TEST']
	    filelist = @test_files || []
	    if filelist.empty?
		if @test_dirs && !@test_dirs.empty?
		    @test_dirs.each { |dir|
			filelist.concat(@rac.sys[File.join(dir, @pattern)])
		    }
		else
		    filelist.concat(@rac.sys[@pattern]) if @pattern
		end
	    end
	    filelist
	end
        def rb_testloader_path
            $LOAD_PATH.each { |libdir|
                path = File.join(libdir, "rant/script/rb_testloader.rb")
                return path if File.exist?(path)
            }
            nil
        end
    end	# class Generators::RubyTest
end	# module Rant
