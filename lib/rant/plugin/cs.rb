
# C# plugin for Rant.

require 'rant/plugin_methods'
require 'rant/cs_compiler'

module RantContext
    # Creates a filetask for building an assembly.  Contrary to a
    # filetask, the block is used to specify attributes for the
    # assembly task, not to build the target.
    def assembly(targ, &block)
	rantapp.assembly(targ, &block)
    end
end
    
module Rant

    class RantApp
	def assembly(targ, &block)
	    prepare_task(targ, nil) { |name,pre,blk|
		AssemblyTask.new(self, name, pre, &block)
	    }
	end
    end # class RantApp

    class AssemblyTask < FileTask

	class << self
	    def csc
		@csc
	    end
	    def csc= new_csc
		case new_csc
		when CsCompiler
		    @csc = new_csc
		when String
		    @csc = CsCompiler.new(
			Rant::CsCompiler.cs_compiler_name(new_csc))
		    @csc.cc = new_csc
		when nil
		    @csc = nil
		else
		    self.csc = new_csc.to_s
		end
		@csc
	    end
	end
	@csc = nil

	# Compiler to use. Can be one of "csc", "mcs" or "cscc". Note
	# that this doesn't decide what compiler *program* will be
	# called, it decides what interface to use for the compiler.
	attr_accessor :cc

	# Compiler program. Usually a program on your path, or you can
	# give an absolute path. Defaults to +cc+.
	attr_accessor :cc_bin

	# This object has to respond to at least the same methods as
	# defined in the Rant::CsCompiler module.
	attr_accessor :compiler

	# Maybe:
	# ["object"]
	#	Compile to object code. Not *that* usual for .NET.
	# ["dll"]
	#	Create a shared library (also called DLL).
	# ["exe"]
	#	Create an executable.
	attr_accessor :target

	def initialize(*args, &init_block)
	    super
	    @init_block = init_block
	end

	#--
	# We delay the call of the initialization block until the
	# target will actually be run. This allows variables to be
	# overridden after task definition and probably saves some
	# instructions (if the task won't be run).
	#++

	def run
	    # setup compiler interface
	    @compiler = Plugin::Cs.csc_for_task(self)
	    @compiler ||= (self.class.csc.nil? ? nil : self.class.csc.dup)
	    if @compiler
		@cc = @compiler.name
	    else
		@cc_bin = nil
		csc = (ENV["CSC"] || ENV["CC"])
		case csc
		when /csc(\.exe)$/i
		    @cc = "csc"
		when /cscc(\.exe)$/i
		    @cc = "cscc"
		when /mcs(\.exe)$/i
		    @cc = "mcs"
		else
		    @cc = nil
		end
		if Env.on_windows?
		    @cc ||= "csc"
		else
		    @cc ||= "cscc"
		end
		@compiler = CsCompiler.new(@cc)
	    end
	    # set target type
	    @target = case @name
	    when /\.exe$/i: "exe"
	    when /\.dll$/i: "dll"
	    when /\.obj$/i: "object"
	    else "exe"
	    end
	    # call initialization block
	    @init_block[self] if @init_block
	    # allow easy override of compiler path
	    @compiler.cc = @cc_bin if @cc_bin
	    @compiler.out = @name
	    # Use prerequisites as sources if no explicit sources
	    # given.
	    @compiler.sources ||= prerequisites

	    @block = lambda { |t|
		::Rant::FileUtils.sh(@compiler.send("cmd_" + @target))
	    }

	    # actually run task
	    super
	end

	# Redirect messages to compiler interface if possible.
	def method_missing(symbol, *args)
	    if symbol.to_s =~ /^cc_(.+)$/ &&
		    compiler.respond_to?($1.to_sym)
		compiler.send($1, *args)
	    elsif compiler.respond_to?(symbol)
		compiler.send(symbol, *args)
	    else
		super
	    end
	end
    end	# class AssemblyTask

end	# module Rant

module Rant::Plugin

    class Cs
	include ::Rant::PluginMethods

	@plugin_object = nil
	class << self

	    attr_accessor :plugin_object

	    def csc_for_task(task)
		if @plugin_object
		    @plugin_object.csc_for_task(task)
		else
		    nil
		end
	    end
	end

	# Shortcut for rant_plugin_name.
	attr_reader :name
	# A "configure" plugin.
	attr_accessor :config
	# A compiler interface with settings resulting from config.
	attr_reader :config_csc

	def initialize(name = nil, app = ::Rant.rantapp)
	    @name = name || rant_plugin_type
	    @app = app or raise ArgumentError, "no application given"
	    @config_csc = nil
	    @config = nil

	    self.class.plugin_object = self
	    @app.plugin_register self

	    yield self if block_given?

	    define_config_checks
	end

	def csc_for_task(task)
	    @config_csc ||= csc_from_config
	    @config_csc.nil? ? nil : @config_csc.dup
	end

	def define_config_checks
	    return unless @config
	    @config.check "csc" do |c|
		c.default "cscc"
		c.guess {
		    Rant::CsCompiler.look_for_cs_compiler
		}
		c.interact {
		    c.prompt "Command to invoke your C# Compiler: "
		}
		c.react {
		    c.msg "Using `#{c.value}' as C# compiler."
		}
	    end
	    @config.check "csc-optimize" do |c|
		c.default true
		c.interact {
		    c.ask_yes_no "Optimize C# compilation?"
		}
	    end
	    @config.check "csc-debug" do |c|
		c.default false
		c.interact {
		    c.ask_yes_no "Compile C# sources for debugging?"
		}
	    end
	end

	def csc_from_config
	    return nil unless @config
	    return nil unless @config.configured?
	    csc_bin = @config["csc"]
	    csc = Rant::CsCompiler.new(
		Rant::CsCompiler.cs_compiler_name(csc_bin))
	    csc.cc = csc_bin if csc_bin
	    csc.optimize = @config["csc-optimize"]
	    csc.debug = @config["csc-debug"]
	    csc
	end

	###### methods override from PluginMethods ###################
	def rant_plugin_type
	    "cs"
	end
	def rant_plugin_name
	    @name
	end
	##############################################################
    end
end
