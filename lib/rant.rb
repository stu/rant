#!/usr/bin/env ruby

require 'rant/rantlib'
require 'rant/env'
require 'rant/rantfile'

module Rant
    VERSION	= '0.0.1'

    CONFIG_FN	= 'config'

    class RantAbortException < StandardError
    end

    class RantDoneException < StandardError
    end

    @rantapp = nil

    class << self

	# Run a new rant application in the current working directory.
	# This has the same effect as running +rant+ from the
	# commandline. You can give arguments as you would give them
	# on the commandline.  If no argument is given, ARGV will be
	# used.
	#
	# This method returns 0 if the rant application was
	# successfull and 1 on failure. So if you need your own rant
	# startscript, it could look like:
	#
	#	exit Rant.run
	#
	# This runs rant in the current directory, using the arguments
	# given to your script and the exit code as suggested by the
	# rant application.
	#
	# Or if you want rant to always be quiet with this script,
	# use:
	#
	#	exit Rant.run("--quiet", ARGV)
	#
	# Of course, you can invoke rant directly at the bottom of
	# your rantfile, so you can run it directly with ruby.
	def run(first_arg=nil, *other_args)
	    other_args = other_args.flatten
	    app = Rant::RantApp.new(
		first_arg.nil? ? ARGV.dup : ([first_arg] + other_args))
	    app.run
	end

	def rantapp
	    @rantapp
	end
	def rantapp=(app)
	    @rantapp = app
	end
    end

    def ensure_rantapp
	# the new app registers itself with
	# Rant.rantapp=
	Rant::RantApp.new unless @rantapp
    end

    def task targ, &block
	ensure_rantapp
	@rantapp.task(targ, &block)
    end

    def file targ, &block
	ensure_rantapp
	@rantapp.file(targ, &block)
    end

    def abort_rant
	if @rantapp
	    @rantapp.abort
	else
	    $stderr.puts "rant aborted!"
	    exit 1
	end
    end

    module_function :task, :file, :abort_rant
    module_function :ensure_rantapp

end	# module Rant

class Rant::RantApp
    include Rant::Console

    HELP	= <<HELP
rant [-f RANTFILE] [OPTIONS] targets...

Options:
    --help
	Print this help and exit.
    --verbose -v
	Turn on verbose mode, can be given multiple times.
    --quiet
	Suppress most messages of rant.
HELP

    # Arguments, usually those given on commandline.
    attr_reader :args
    # A hash of options influencing this app.
    # Commandline options are mapped to this hash.
    attr_reader :opts
    # A list of all Rantfiles used by this app.
    attr_reader :rantfiles

    def initialize *args
	@args = args.flatten
	@rantfiles = []
	Rant.rantapp = self
	@opts = {
	    # this will be a number, if given
	    :verbose	=> false,
	    :quiet	=> false,
	}
	@arg_rantfiles = []	# rantfiles given in args
	@arg_targets = []	# targets given in args
    end

    # Returns 0 on success and 1 on failure.
    def run
	process_args
	
	return 0
    rescue Rant::RantDoneException
	return 0
    rescue Rant::RantAbortException
	$stderr.puts "rant aborted!"
	return 1
    end

    def task targ, &block
	prepare_task(targ, block) { |name,pre,blk|
	    Rant::Task.new(name, pre, &blk)
	}
    end

    def file targ, &block
	prepare_task(targ, block) { |name,pre,blk|
	    Rant::FileTask.new(name, pre, &blk)
	}
    end

    def abort *msg
	err_msg(msg) unless msg.empty?
	raise Rant::RantAbortException
    end

    private
    def process_args
	@args.each { |arg|
	    case arg
	    when "-v": more_verbose
	    when "--verbose": more_verbose
	    when "-q"
		@opts[:quiet] = true
		@opts[:verbose] = false
	    when "--quiet"
		@opts[:quiet] = true
		@opts[:verbose] = false
	    when "--version"
		$stdout.puts "rant #{Rant::VERSION}"
		raise Rant::RantDoneException
	    when "--help"
		$stdout.print HELP
		raise Rant::RantDoneException
	    else
		if arg =~ /^\-{1,2}[^\-]+/
		    abort("Unknown option `#{arg}'.",
			"Type `#$0 --help' for usage.")
		end
		@arg_targets << arg
	    end
	}
    end

    def more_verbose
	verbose ? (@opts[:verbose] += 1) : (@opts[:verbose] = 1)
	@opts[:quiet] = false
    end
    def verbose
	@opts[:verbose]
    end
    def quiet?
	@opts[:quiet]
    end

    def pos_text file, ln
	t = "in file `#{file}'"
	if ln && ln > 0
	    t << ", line #{ln}"
	end
	t + ": "
    end

    def prepare_task targ, block
	ch = Rant::Lib::parse_caller_elem(caller[1])
	name = nil
	pre = []
	ln = ch[:ln] || 0
	file = ch[:file]
	if targ.is_a?(String) || targ.is_a?(Symbol)
	    name = targ.to_s
	elsif targ.respond_to? :to_str
	    name = targ.to_str
	elsif targ.is_a? Hash
	    if targ.empty?
		abort(pos_text(file, ln),
		    "Empty hash as task argument, " +
		    "task name required.")
	    end
	    if targ.size > 1
		abort(pos_text(file, ln),
		    "Too many hash elements, " +
		    "should only be one.")
	    end
	    targ.each_pair { |k,v|
		if k.is_a?(String) || k.is_a?(Symbol)
		    name = k.to_s
		elsif k.respond_to? :to_str
		    name = k.to_str
		else
		    abort(pos_text(file, ln),
			"Task name has to be a string or symbol.")
		end
		pre = v
	    }
	    pre = [pre] unless pre.is_a? Enumerable
	end
	if @rantfiles.include? file
	    file = @rantfiles.find { |f| f == file }
	else
	    file = Rant::Rantfile.new(file)
	    @rantfiles << file
	end
	nt = yield(name, pre, block)
	nt.rantfile = file
	nt.line_number = ln
	file.tasks << nt
	nt
    end

####### TODO #########################################################
    # Returns true on success, nil on failure.
    def init_config
        unless File.exist? CONFIG_FN
            return nil unless autoconf(true)
        end
        ret_attrs = read_config
        unless ret_attrs
            if ask_yes_no "Configuration invalid, reconfigure now?"
                begin
                    File.unlink CONFIG_FN
                rescue
                    warn_msg $1.message
                end
                if File.exist? CONFIG_FN
                    err_msg "Can't remove invalid config file `#{CONFIG_FN}'.",
                        "Please remove by hand!"
                    return nil
                end
                return init_config
            else
                return nil
            end
        end
        @attrs.merge! ret_attrs
        @config_success = true
    end

    # Returns nil on failure.
    def read_yaml_config(fn = CONFIG_FN)
        File.open(fn) { |file|
            YAML.load_documents(file) { |doc|
                if doc.is_a? Hash
                    return doc.dup
                else
                    err_msg "Invalid config file `#{config}'.",
                        "Please remove this file or reconfigure."
                    return nil
                end
            }
        }
    rescue
        err_msg "When attempting to read config: " + $!.message
        nil
    end

    # Write configuration (attrs) to fn.
    # Returns nil on failure.
    def write_config(fn, attrs)
        File.open(fn, "w") { |file|
            file << attrs.to_yaml
            file << "\n"
        }
        return true
    rescue
        err_msg "When writing configuration: " + $!.message,
            "Ensure writing to file (doesn't need to exist) `#{fn}'",
            "is possible and try to reconfigure!"
        nil
    end

    # Write current settings.
    # Return nil on failure, true otherwise.
    def save
        if write_config CONFIG_FN, @attrs
            msg "Configuration written to `#{CONFIG_FN}'."
            true
        else
            err_msg "Fail to write configuration."
            nil
        end
    end
######################################################################

end	# class Rant::RantApp

if $0 == __FILE__
    exit Rant.run
end
