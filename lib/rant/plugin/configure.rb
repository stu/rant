
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
    #	conf = plugin :Configure do |conf|
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

	class << self
	    def rant_plugin_new(app, cinf, *args, &block)
		if args.size > 1
		    app.abort(app.pos_text(cinf[:file], cinf[:ln]),
			"Configure plugin takes only one argument.")
		end
		self.new(app, args.first, &block)
	    end
	end

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
	# Let the environment set values. A change through an
	# environment variable will be reflected in the configuration
	# file.
	# Defaults to true.
	#
	# Note: The environment always overrides the default values
	# after startup, but it doesn't override whats written in the
	# configuration file if this value is set to false.
	attr_accessor :env_overrides

	def initialize(app, name = nil)
	    @name = name || rant_plugin_type
	    @app = app or raise ArgumentError, "no application given"
	    @file = "config"
	    @checklist = []
	    @startup_mode = :defaults
	    @no_write = false
	    @modified = false
	    @no_action_list = ["distclean", "clobber", "clean"]
	    @no_action = false
	    @configured = false
	    @env_overrides = true

	    yield self if block_given?
	    run_checklist(:defaults)
	    # we don't need to save our defaults
	    @modified = false
	end

	def [](key)
	    c = checklist.find { |c| c.key == key }
	    c ? c.value : nil
	end
	# Creates new check with default value if key doesn't exist.
	def []=(key, val)
	    @modified = true
	    c = checklist.find { |c| c.key == key }
	    if c
		c.value = val
	    else
		self.check(key) { |c|
		    c.default val
		}
	    end
	end

	# Sets the specified check if a check with the given key
	# exists.
	# Returns the value if it was set, nil otherwise.
	def set_if_exists(key, value)
	    c = checklist.find { |c| c.key == key }
	    if c
		c.value = value
		@modified = true
	    else
		nil
	    end
	end

	# Builds a hash with all key-value pairs from checklist.
	def data
	    hsh = {}
	    @checklist.each { |c|
		hsh[c.key] = c.value
	    }
	    hsh
	end

	# This is true, if either a configure task was run, or the
	# configuration file was read.
	def configured?
	    @configured
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
		@configured = true
	    }
	    nt
	end

	def check(key, hsh = {}, &block)
	   checklist << ConfigureCheck.new(key, hsh, &block) 
	end

	# Run the configure process in the given mode.
	def run_checklist(mode = :guess_interact)
	    @checklist.each { |c|
		c.run_check(mode)
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
	    if @env_overrides
		ENV.each_pair { |k, v|
		    set_if_exists(k, v)
		}
	    end
	    @configured = true
	end

	def write_yaml
	    @app.msg 1, "Writing config to `#{@file}'."
	    File.open(@file, "w") { |f|
		f << data.to_yaml
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
			doc.each_pair { |k, v|
			    self[k] = v
			}
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
	
	public :msg, :prompt, :ask_yes_no

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

	    # let ENV override value
	    ev = ENV[@key]
	    @value = ev unless ev.nil?
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

	# Before doing anything else, this looks in ENV if it has a
	# value that is not +nil+ and uses that as default.
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
	    # look in ENV first
	    ev = ENV[@key]
	    @value = ev unless ev.nil?
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
