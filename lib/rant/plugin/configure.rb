
require 'rant/plugin_methods'
require 'yaml'

# Configure plugin for Rant

module Rant::Plugin

    # === Startup of configure plugin
    # ==== Config file exists
    # The configuration file will be read and the data hash
    # set up accordingly.
    # ==== Config file doesn't exist
    # The configuration process is run with +startup_modes+ which
    # has to be one of CHECK_MODES. +startup_modes+ defaults to
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
		:default,
		:env,
		:guess,
		:interact,
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

	# Decide what the configure plugin does on startup if the
	# configuration file doesn't exist. Initialized to
	# <tt>[:guess]</tt>.
	attr_accessor :init_modes

	# Decide what the configure plugin does *after* reading the
	# configuration file (or directly after running +init_modes+
	# if the configuration file doesn't exist).
	# Initialized to <tt>[:env]</tt>, probably the only usefull
	# value.
	attr_accessor :override_modes

	# Don't write to file, config values will be lost when
	# rant exits!
	attr_accessor :no_write

	# Don't read or write to configuration file nor run +guess+ or
	# +interact+ blocks if *first* target given on commandline
	# is in this list. This is usefull for targets that remove
	# the configuration file.
	# Defaults are "distclean", "clobber" and "clean".
	attr_reader :no_action_list

	def initialize(app, name = nil)
	    @name = name || rant_plugin_type
	    @app = app or raise ArgumentError, "no application given"
	    @file = "config"
	    @checklist = []
	    @init_modes = [:guess]
	    @override_modes = [:env]
	    @no_write = false
	    @modified = false
	    @no_action_list = ["distclean", "clobber", "clean"]
	    @no_action = false
	    @configured = false

	    yield self if block_given?

	    run_checklist([:default])
	    # we don't need to save our defaults
	    @modified = false
	end

	# Get the value for +key+ from +checklist+ or +nil+ if there
	# isn't a check with the given +key+.
	def [](key)
	    c = checklist.find { |c| c.key == key }
	    c ? c.value : nil
	end

	# Creates new check with default value if key doesn't exist.
	def []=(key, val)
	    c = checklist.find { |c| c.key == key }
	    if c
		if c.value != val
		    c.value = val
		    @modified = true
		end
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
	# process in the given +check_modes+. If no task name is given
	# or it is +nil+, the plugin name will be used as task name.
	def task(name = nil, check_modes = [:guess, :interact])
	    name ||= @name
	    cinf = ::Rant::Lib.parse_caller_elem(caller[0])
	    file = cinf[:file]
	    ln = cinf[:ln] || 0
	    if !Array === check_modes || check_modes.empty?
		@app.abort(@app.pos_text(file, ln),
		    "check_modes given to configure task has to be an array",
		    "containing at least one CHECK_MODE symbol")
	    end
	    check_modes.each { |cm|
		unless CHECK_MODES.include? cm
		    @app.abort(@app.pos_text(file,ln),
			"Unknown checkmode `#{cm.to_s}'.")
		end
	    }
	    nt = @app.task(name) { |t|
		run_checklist(check_modes)
		save
		@configured = true
	    }
	    nt
	end

	def check(key, val = nil, &block)
	   checklist << ConfigureCheck.new(key, val, &block) 
	end

	# Run the configure process in the given modes.
	def run_checklist(modes = [:guess, :interact])
	    @checklist.each { |c|
		c.run_check(modes)
	    }
	    @modified = true
	end

	# Write configuration if modified.
	def save
	    return if @no_write
	    write_yaml if @modified
	    true
	end

	# Immediately write configuration to +file+.
	def write
	    write_yaml
	    @modified = false
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
	    if File.exist? @file
		read_yaml
		@configured = true
	    elsif !@init_modes == [:default]
		run_checklist @init_modes
	    end
	    if @override_modes && !@override_modes.empty?
		run_checklist @override_modes
	    end
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
	attr_accessor :default
	attr_accessor :guess_block
	attr_accessor :interact_block
	attr_accessor :react_block
	def initialize(key, val = nil)
	    @key = key or raise ArgumentError, "no key given"
	    @value = @default = val
	    @guess_block = nil
	    @interact_block = nil
	    @react_block = nil
	    yield self if block_given?
	end
	def default(val)
	    @default = val
	    @value = @default if @value.nil?
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

	# Run checks as specified by +modes+. +modes+ has to be a list
	# of symbols from the Configure::CHECK_MODES.
	def run_check(modes = [:guess], env = ENV)
	    val = nil
	    modes.each { |mode|
		case mode
		when :default
		    val = @default
		when :env
		    val = env[@key]
		when :interact
		    val = @interact_block[self] if @interact_block
		when :guess
		    val = @guess_block[self] if @guess_block
		else
		    raise "unknown configure mode"
		end
		break unless val.nil?
	    }
	    val.nil? or @value = val
	    @react_block && @react_block[@value]
	    @value
	end
    end	# class ConfigureCheck
end	# module Rant::Plugin
