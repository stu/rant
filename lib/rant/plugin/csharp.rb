
# C# plugin for Rant.

require 'rant/plugin_methods'
require 'rant/cs_compiler'

module Rant

    class Generators::Assembly < CsCompiler
	class << self

	    def rant_generate(app, clr, args, &block)
		assembly = self.new(&block)
		if args.size == 1
		    targ = args.first
		    # embed caller information for correct resolving
		    # of source Rantfile
		    if targ.is_a? Hash
			targ[:__caller__] = clr
		    else
			targ = { :__caller__ => clr, targ => [] }
		    end
		    app.prepare_task(targ, nil) { |name,pre,blk|
			assembly.out = name
			t = AssemblyTask.new(app, assembly, &block)
			# TODO: optimize
			pre.each { |e| t << e }
			t
		    }
		else
		    cinf = ::Rant::Lib.parse_caller_elem(clr)
		    app.abort(app.pos_text(cinf[:file], cinf[:ln]),
			"Assembly takes one argument, " +
			"which should be like one given to the `task' command.")
		end
	    end

	    def csc
		@csc
	    end
	    def csc= new_csc
		case new_csc
		when CsCompiler
		    @csc = new_csc
		when String
		    @csc = CsCompiler.new(
			CsCompiler.cs_compiler_name(new_csc))
		    @csc.csc_bin = new_csc
		when nil
		    @csc = nil
		else
		    self.csc = new_csc.to_s
		end
		@csc
	    end
	end
	@csc = nil

	# Maybe:
	# ["object"]
	#	Compile to object code. Not *that* usual for .NET.
	# ["dll"]
	#	Create a shared library (also called DLL).
	# ["exe"]
	#	Create an executable.
	attr_accessor :target

	def initialize(comp = nil, &init_block)
	    super()
	    @target = nil
	    @init_block = init_block
	    take_common_attrs comp if comp
	end

	# Synonym for +out+.
	def name
	    out
	end

	# Synonym for +out=+.
	def name=(new_name)
	    out = new_name
	end

	# Take common attributes like +optimize+, +csc+ and similar
	# from the compiler object +comp+.
	def take_common_attrs comp
	    @csc_name = comp.csc_name
	    @long_name = comp.long_name
	    @csc_bin = comp.csc_bin
	    @debug = comp.debug
	    comp.defines.each { |e|
		@defines << e unless @defines.include? e
	    }
	    comp.lib_link_pathes.each { |e|
		@lib_link_pathes << e unless @lib_link_pathes.include?  e
	    }
	    @optimize = comp.optimize
	    @warnings = comp.warnings
	    # TODO: we currently take unconditionally all misc- and
	    # compiler specific args
	    comp.misc_args.each { |e|
		@misc_args << e unless @misc_args.include? e
	    }
	    comp.specific_args.each_pair { |k,v|
		# k is a compiler name, v is a list of arguments
		# specific to this compiler type.
		cst = @specific_args[k]
		unless cst
		    @specific_args[k] = v
		    next
		end
		v.each { |e|
		    cst << e unless cst.include? e
		}
	    }
	end

	# Call the initialization block and intialize compiler
	# interface.
	def init
	    # setup compiler interface
	    comp = Plugin::Csharp.csc_for_assembly(self) || self.class.csc
	    take_common_attrs comp if comp

	    # call initialization block
	    @init_block[self] if @init_block

	    # set target type
	    unless @target
		@target = case @out
		when /\.exe$/i: "exe"
		when /\.dll$/i: "dll"
		when /\.obj$/i: "object"
		else "exe"
		end
	    end
	    # TODO: verify some attributes like @target
	end

	def compile
	    ::Rant::Sys.sh(self.send("cmd_" + @target))
	end

    end	# class Generators::Assembly

    class AssemblyTask < FileTask
	def initialize(app, assembly)
	    @assembly = assembly
	    super(app, @assembly.out) { |t|
		app.context.sys assembly.send("cmd_" + assembly.target)
	    }
	end
=begin
	def resolve_prerequisites
	    @assembly.init
	    @pre.concat(@assembly.sources)
	    @pre.concat(@assembly.resources) if @assembly.resources
	    super
	end
=end
	def invoke(force = false)
	    @assembly.init
	    @pre.concat(@assembly.sources)
	    @pre.concat(@assembly.resources) if @assembly.resources
	    super
	end
    end
end	# module Rant

module Rant::Plugin

    # This plugin class is currently designed to be instantiated only
    # once with +rant_plugin_new+.
    class Csharp
	include ::Rant::PluginMethods

	@plugin_object = nil
	class << self

	    def rant_plugin_new(app, cinf, *args, &block)
		if args.size > 1
		    app.abort(app.pos_text(cinf[:file], cinf[:ln]),
			"Csharp plugin takes only one argument.")
		end
		self.new(app, args.first, &block)
	    end

	    attr_accessor :plugin_object

	    def csc_for_assembly(task)
		if @plugin_object
		    @plugin_object.csc_for_assembly(task)
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

	def initialize(app, name = nil)
	    @name = name || rant_plugin_type
	    @app = app or raise ArgumentError, "no application given"
	    @config_csc = nil
	    @config = nil

	    self.class.plugin_object = self

	    yield self if block_given?

	    define_config_checks
	end

	def csc_for_assembly(assembly)
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
		#c.react {
		#    c.msg "Using `#{c.value}' as C# compiler."
		#}
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
	    #puts "using csc from config: " + csc_bin
	    csc = Rant::CsCompiler.new
	    csc.csc = csc_bin
	    csc.optimize = @config["csc-optimize"]
	    csc.debug = @config["csc-debug"]
	    csc
	end

	###### methods override from PluginMethods ###################
	def rant_plugin_type
	    "csharp"
	end
	def rant_plugin_name
	    @name
	end
	##############################################################
    end # class Csharp
end	# module Rant::Plugin
