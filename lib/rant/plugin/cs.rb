
# C# plugin for Rant.

require 'rant/plugin_methods'
require 'rant/cs_compiler'

module Rant

    # Creates a filetask for building an assembly.
    # Contrary to a filetask, the block is used to specify attributes
    # for the assembly task, not to build the target.
    def assembly(targ, &block)
	Rant.rantapp.assembly(targ, &block)
    end
    
    class RantApp
	def assembly(targ, &block)
	    prepare_task(targ, nil) { |name,pre,blk|
		AssemblyTask.new(self, name, pre)
	    }
	end
    end # class RantApp

    class AssemblyTask < FileTask

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

	def initialize(*args)
	    super
	    
	    @cc_bin = nil
	    csc ||= (ENV["CSC"] || ENV["CC"])
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
	    @target = case @name
	    when /\.exe$/i: "exe"
	    when /\.dll$/i: "dll"
	    when /\.obj$/i: "object"
	    else "exe"
	    end

	    yield self if block_given?
	    @compiler.cc = @cc_bin if @cc_bin
	    @compiler.out = @name
	    @compiler.sources ||= prerequisites

	    @block = lambda { |t|
		::Rant::FileUtils.sh(case @target
		when "exe": @compiler.cmd_exe
		when "shared": @compiler.cmd_shared
		when "object": @compiler.cmd_object
		else raise "assembly: unknown target type `#{@target}'"
		end)
	    }
	end

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
