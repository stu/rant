
require 'rant/plugin_methods'
require 'yaml'

# Configure plugin for Rant

module Rant::Plugin

    # === Startup of configure plugin
    # ==== Config file exists
    # The configuration file will be read and the data hash
    # set up accordingly.
    # ==== Config file doesn't exist
    # The configuration process is run with +startup_mode+ which
    # has to be one of CHECK_MODES. +startup_mode+ defaults to
    # :default, which means if the configfile doesn't exist,
    # all values will be set to their defaults on startup.
    # === Access to configuration in Rantfile
    # You can access all configuration values through the <tt>[]</tt>
    # and <tt>[]=</tt> operators of the configure plugin.
    #
    # Example of configure in Rantfile:
    #
    #	conf = Plugin::Configure.new doc |conf|
    #	    conf.task	# define a task named :configure
    #	    conf.check "profile" do |c|
    #		c.default "full"
    #		c.guess { ENV["PROFILE"] }
    #		c.interact {
    #		    conf.prompt "What build-profile should be used?"
    #		}
    #	    end
    #	    conf.check "optimize" do |c|
    #           c.default true
    #           c.guess { ENV["OPTIMIZE"] }
    #           c.interact {
    #               conf.ask_yes_no "Optimize build?"
    #           }
    #       end
    #   end
    #
    #   # Set default target depending on profile:
    #   task :default => conf["profile"]
    class Configure
	include ::Rant::PluginMethods
	include ::Rant::Console

	CHECK_MODES	= [
		:interact,
		:defaults,
		:guess,
		:guess_interact,
	    ]
	
	# Name for this plugin instance. Defaults to "configure".
	attr_reader :name
	# Name of configuration file.
	attr_accessor :file
	# A hash with all configuration data.
	attr_reader :data
	# This flag is used to determine if data has changed and
	# should be saved to file.
	attr_accessor :modified
	# An array with all checks to perform.
	attr_reader :checklist
	# Decide what the configure plugin does on startup.
	attr_accessor :startup_mode
	# Don't write to file, config values will be lost when
	# rant exits!
	attr_accessor :no_write
	# Don't do anything if *first* target given on commandline
	# is in this list. This is usefull for targets that remove
	# the configuration file.
	# Defaults are "distclean", "clobber" and "clean".
	attr_reader :no_action_list

	def initialize(name = nil, app = ::Rant.rantapp)
	    @name = name || rant_plugin_type
	    @app = app or raise ArgumentError, "no application given"
	    @file = "config"
	    @data = {}
	    @checklist = []
	    @startup_mode = :defaults
	    @no_write = false
	    @modified = false
	    @no_action_list = ["distclean", "clobber", "clean"]
	    @no_action = false

	    yield self if block_given?
	    run_checklist(:defaults)
	    # we don't need to save our defaults
	    @modified = false

	    @app.plugin_register(self)
	end

	def [](key)
	    @data[key]
	end
	def []=(key, val)
	    @modified = true
	    @data[key] = val
	end

	# Define a task with +name+ that will run the configuration
	# process in the given +check_mode+.
	def task(name = nil, check_mode = :guess_interact)
	    name ||= @name
	    cinf = ::Rant::Lib.parse_caller_elem(caller[0])
	    file = cinf[:file]
	    ln = cinf[:ln] || 0
	    unless CHECK_MODES.include? check_mode
		@app.abort(@app.pos_text(file,ln),
		    "Unknown checkmode `#{check_mode.to_s}'.")
	    end
	    nt = @app.task(name) { |t|
		run_checklist(check_mode)
		save
	    }
	    nt
	end

	def check(key, hsh = {}, &block)
	   checklist << ConfigureCheck.new(key, hsh, &block) 
	end

	# Run the configure process in the given mode.
	def run_checklist(mode = :guess_interact)
	    @checklist.each { |c|
		@data[c.key] = c.run_check(mode)
	    }
	    @modified = true
	end

	# Write configuration if modified.
	def save
	    return if @no_write
	    write_yaml if @modified
	    @modified = false
	    true
	end

	# Immediately write configuration to +file+.
	def write
	    write_yaml
	end

	###### overriden plugin methods ##############################
	def rant_plugin_type
	    "configure"
	end

	def rant_plugin_name
	    @name
	end

	def rant_plugin_init
	    @no_action = @no_action_list.include? @app.cmd_targets.first
	    @no_action || init_config
	end

	def rant_plugin_stop
	    @no_action || save
	end
	##############################################################

	private

	# Returns true on success, nil on failure.
	def init_config
	    unless File.exist? @file
		return if @startup_mode == :defaults
		if CHECK_MODES.include?(@startup_mode)
		    return run_checklist(@startup_mode)
		else
		    @app.plugin_warn("Unknown startup mode " + 
			"`#{@startup_mode.to_s}' for #{@name} module.")
		    return run_checklist(:defaults)
		end
	    end
	    read_yaml
	end

	def write_yaml
	    @app.msg 1, "Writing config to `#{@file}'."
	    File.open(@file, "w") { |f|
		f << @data.to_yaml
		f << "\n"
	    }
	    true
	rescue
	    @app.abort("When writing configuration: " + $!.message,
	    "Ensure writing to file (doesn't need to exist) `#{@file}'",
	    "is possible and try to reconfigure!")
	end

	def read_yaml
	    File.open(@file) { |f|
		YAML.load_documents(f) { |doc|
		    if doc.is_a? Hash
			@data.merge!(doc)
		    else
			@app.abort("Invalid config file `#{@file}'.",
			    "Please remove this file or reconfigure.")
		    end
		}
	    }
	rescue
	    @app.abort("When attempting to read config: " + $!.message)
	end

    end	# class Configure
    class ConfigureCheck
	include ::Rant::Console

	attr_reader :key
	attr_accessor :value
	attr_accessor :guess_block
	attr_accessor :interact_block
	attr_accessor :react_block
	def initialize(key, hsh)
	    @key = key or raise ArgumentError, "no key given"
	    @value = hsh[:value]
	    @default = hsh[:default]
	    @guess_block = hsh[:guess]
	    @interact_block = hsh[:interact]
	    yield self if block_given?
	end
	def default(val)
	    @value = val
	end
	def guess(&block)
	    @guess_block = block
	end
	def interact(&block)
	    @interact_block = block
	end
	def react(&block)
	    @react_block = block
	end

	# Four possible modes:
	# [:interact]
	#	Run interact block if given.
	# [:defaults]
	#	Just use default value.
	# [:guess]
	#	Run the guess block if given.
	# [:guess_interact]
	#	Run the guess block first, if it gives nil,
	#	run the interact block.
	def run_check(mode = :guess)
	    val = nil
	    case mode
	    when :interact
		val = @interact_block[self] if @interact_block
	    when :defaults
		# nothing to do here
	    when :guess
		val = @guess_block[self] if @guess_block
	    when :guess_interact
		val = @guess_block[self] if @guess_block
		val = @interact_block[self] if val.nil? && @interact_block
	    else
		raise "unknown configure mode"
	    end
	    val.nil? || @value = val
	    @react_block && @react_block[@value]
	    @value
	end
    end	# class ConfigureCheck
end	# module Rant::Plugin
