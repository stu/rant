
require 'rant/plugin_methods'
require 'yaml'

# Configure plugin for Rant

module Rant::Plugin
    class Configure
	include ::Rant::PluginMethods
	include ::Rant::Console

	CHECK_MODES	= [
		:interact,
		:defaults,
		:guess,
		:guess_interact,
	    ]
	
	# Name of configuration file.
	attr_accessor :file
	# A hash with all configuration data.
	attr_reader :data
	# This flag is used to determine if data has changed and
	# should be saved to file.
	attr_accessor :modified
	# An array with all checks to perform.
	attr_reader :checklist

	def initialize(app = ::Rant.rantapp)
	    @app = app or raise ArgumentError, "no application given"
	    @file = "config"
	    @data = {}
	    @checklist = []

	    yield self if block_given?

	    @app.plugin_register(self)
	end

	def [](key)
	    @data[key]
	end
	def []=(key, val)
	    @modified = true
	    @data[key] = val
	end

	def task(name = :configure, check_mode = :guess_interact)
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

	def run_checklist(mode = :guess_interact)
	    @checklist.each { |c|
		@data[c.key] = c.run_check(mode)
	    }
	    @modified = true
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

	def save
	    write_yaml if @modified
	    @modified = false
	    true
	end

	# Returns true on success, nil on failure.
	def init_config
	    # TODO
	    unless File.exist? @file
		run_checklist(:defaults)
		return save
	    end
	    read_yaml
	end

	###### overriden plugin methods ##############################
	def rant_plugin_name
	    "configure"
	end

	def rant_plugin_init
	    init_config
	end

	def rant_plugin_stop
	    save
	end
	##############################################################

    end	# class Configure
    class ConfigureCheck
	include ::Rant::Console

	attr_reader :key
	attr_accessor :default
	attr_accessor :value
	attr_accessor :guess_block
	attr_accessor :interact_block
	def initialize(key, hsh)
	    @key = key or raise ArgumentError, "no key given"
	    @value = hsh[:value]
	    @default = hsh[:default]
	    @guess_block = hsh[:guess]
	    @interact_block = hsh[:interact]
	    yield self if block_given?
	end
	def guess(&block)
	    @guess_block = block
	end
	def interact(&block)
	    @interact_block = block
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
	    @value = val.nil? ? @default : val
	end
    end	# class ConfigureCheck
end	# module Rant::Plugin
