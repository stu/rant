
require 'getoptlong'
require 'rant/rantlib'

module Rant

    class RantImportDoneException < RantDoneException
    end

    class RantImportAbortException < RantAbortException
    end

    class RantImport
	include Rant::Console

	LIB_DIR = File.expand_path(File.dirname(__FILE__))

	OPTIONS = [
	    [ "--help",		"-h",	GetoptLong::NO_ARGUMENT,
		"Print this help and exit."			],
	    [ "--version",	"-v",	GetoptLong::NO_ARGUMENT,
		"Print version of rant-import and exit."	],
	    [ "--plugins",	"-p",	GetoptLong::REQUIRED_ARGUMENT,
		"Include PLUGINS (comma separated list)."	],
	    [ "--imports",	"-i",	GetoptLong::REQUIRED_ARGUMENT,
		"Include IMPORTS (coma separated list)."	],
	    [ "--force",	"-f",	GetoptLong::NO_ARGUMENT,
		"Force overwriting of output file."		],
	]

	class << self
	    def run(first_arg=nil, *other_args)
		other_args = other_args.flatten
		args = first_arg.nil? ? ARGV.dup : ([first_arg] + other_args)
		new(args).run
	    end
	end

	# Arguments, usually those given on commandline.
	attr :args
	# Plugins to import.
	attr :plugins
	# Imports to import ;)
	attr :imports
	# Filename where the monolithic rant script goes to.
	attr :mono_fn

	def initialize(*args)
	    @args = args.flatten
	    @msg_prefix = "rant-import: "
	    @plugins = []
	    @imports = []
	    @mono_fn = nil
	    @force = false
	    @rantapp = nil
	end

	def run
	    process_args

	    done
	rescue RantImportDoneException
	    0
	rescue RantImportAbortException
	    1
	end

	def process_args
	    # WARNING: we currently have to fool getoptlong,
	    # by temporory changing ARGV!
	    # This could cause problems.
	    old_argv = ARGV.dup
	    ARGV.replace(@args.dup)
	    cmd_opts = GetoptLong.new(*OPTIONS.collect { |lst| lst[0..-2] })
	    cmd_opts.quiet = true
	    cmd_opts.each { |opt, value|
		case opt
		when "--version"
		    puts "rant-import #{Rant::VERSION}"
		    done
		when "--help": help
		when "--force": @force = true
		end
	    }
	    rem_args = ARGV.dup
	    unless rem_args.size == 1 && !@mono_fn
		abort("Exactly one argument (besides options) required.",
		    "Type `rant-import --help' for usage.")
	    end
	    @mono_fn = rem_args.first if rem_args.first
	rescue GetoptLong::Error => e
	    abort(e.message)
	ensure
	    ARGV.replace(old_argv)
	end

	def done
	    raise RantImportDoneException
	end

	def help
	    puts "rant-import [OPTIONS] [-i IMPORT1,IMPORT2,...] [-p PLUGIN1,PLUGIN2...] MONO_RANT"
	    puts
	    puts "  Write a monolithic rant script to MONO_RANT."
	    puts
	    puts "Options are:"
	    print option_listing(OPTIONS)
	    done
	end

	def abort(*text)
	    err_msg *text unless text.empty?
	    raise RantImportAbortException
	end

    end	# class RantImport
end	# module Rant
