
require 'getoptlong'
require 'rant/rantlib'
require 'rant/env'
require 'rant/rantfile'
require 'rant/fileutils'

module Rant end

module Rant::Lib
    
    # Parses one string (elem) as it occurs in the array
    # which is returned by caller.
    # E.g.:
    #	p parse_caller_elem "/usr/local/lib/ruby/1.8/irb/workspace.rb:52:in `irb_binding'"
    # prints:
    #   {:method=>"irb_binding", :ln=>52, :file=>"/usr/local/lib/ruby/1.8/irb/workspace.rb"} 
    def parse_caller_elem elem
	parts = elem.split(":")
	rh = {	:file => parts[0],
		:ln => parts[1].to_i
	     }
	meth = parts[2]
	if meth && meth =~ /\`(\w+)'/
	    meth = $1
	end
	rh[:method] = meth
	rh
    end

    module_function :parse_caller_elem
end

module Rant
    VERSION	= '0.0.1'

    # Those are the filenames for rantfiles.
    # Case doens't matter!
    RANTFILES	= [	"rantfile",
			"rantfile.rb",
			"rant",
			"rant.rb"
		  ]

    CONFIG_FN	= 'config'

    class RantAbortException < StandardError
    end

    class RantDoneException < StandardError
    end

    @@rantapp = nil

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
	    args = first_arg.nil? ? ARGV.dup : ([first_arg] + other_args)
	    if @@rantapp && !@@rantapp.done?
		@@rantapp.args.replace(args.flatten)
		@@rantapp.run
	    else
		app = Rant::RantApp.new(args)
		app.run
	    end
	end

	def rantapp
	    @@rantapp
	end
	def rantapp=(app)
	    @@rantapp = app
	end
    end

    # "Clear" the current Rant application. After this call,
    # Rant has the same state as immediately after startup.
    def reset
	@@rantapp = nil
	Task.all.clear
    end

    def ensure_rantapp
	# the new app registers itself with
	# Rant.rantapp=
	Rant::RantApp.new unless @@rantapp
    end
    private :ensure_rantapp

    def task targ, &block
	ensure_rantapp
	@@rantapp.task(targ, &block)
    end

    def file targ, &block
	ensure_rantapp
	@@rantapp.file(targ, &block)
    end

    def subdirs *args
	ensure_rantapp
	@@rantapp.subdirs(*args)
    end

    def abort_rant
	if @@rantapp
	    @@rantapp.abort
	else
	    $stderr.puts "rant aborted!"
	    exit 1
	end
    end

    module_function :task, :file, :abort_rant, :subdirs
    module_function :ensure_rantapp

end	# module Rant

class Rant::RantApp
    include Rant::Console

    # The RantApp class has no own state.

    OPTIONS	= [
	[ "--help",	"-h",	GetoptLong::NO_ARGUMENT,
	    "Print this help and exit."				],
	[ "--version",	"-V",	GetoptLong::NO_ARGUMENT,
	    "Print version of Rant and exit."			],
	[ "--verbose",	"-v",	GetoptLong::NO_ARGUMENT,
	    "Print more messages to stderr."			],
	[ "--quiet",	"-q",	GetoptLong::NO_ARGUMENT,
	    "Suppress most messages to stderr."			],
	[ "--rantfile",	"-f",	GetoptLong::REQUIRED_ARGUMENT,
	    "Process RANTFILE instead of standard rantfiles.\n" +
	    "Multiple files may be specified with this option"	],
    ]

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
	@ran = false
	@done = false
    end

    def ran?
	@ran
    end

    def done?
	@done
    end

    # Returns 0 on success and 1 on failure.
    def run
	@ran = true
	process_args
	load_rantfiles
	run_tasks
	raise Rant::RantDoneException
    rescue Rant::RantDoneException
	@done = true
	return 0
    rescue Rant::RantAbortException
	$stderr.puts "rant aborted!"
	return 1
    rescue
	err_msg $!.message, $!.backtrace
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

    # Search the given directories for Rantfiles.
    def subdirs *args
	args = args.flatten
	cinf = Rant::Lib::parse_caller_elem(caller[1])
	ln = cinf[:ln] || 0
	file = cinf[:file]
	args.each { |arg|
	    if arg.is_a? Symbol
		arg = arg.to_s
	    elsif arg.respond_to? :to_str
		arg = arg.to_str
	    end
	    unless arg.is_a? String
		abort(pos_text(file, ln),
		    "in `subdirs' command: arguments must be strings")
	    end
	    loaded = false
	    rantfiles_in_dir(arg).each { |f|
		loaded = true
		rf, is_new = rantfile_for_path(f)
		if is_new
		    load_file rf
		end
	    }
	    unless loaded || quiet?
		warn_msg(pos_text(file, ln) + "; in `subdirs' command:",
		    "No Rantfile in subdir `#{arg}'.")
	    end
	}
    rescue SystemCallError => e
	abort(pos_text(file, ln),
	    "in `subdirs' command: " + e.message)
    end

    def abort *msg
	err_msg(msg) unless msg.empty?
	raise Rant::RantAbortException
    end

    def help
	puts "rant [-f RANTFILE] [OPTIONS] targets..."
	puts
	puts "Options are:"
	OPTIONS.each { |lopt, sopt, mode, desc|
	    optstr = ""
	    arg = nil
	    if mode == GetoptLong::REQUIRED_ARGUMENT
		if desc =~ /(\b[A-Z_]{2,}\b)/
		    arg = $1
		end
	    end
	    if lopt
		optstr << lopt
		if arg
		    optstr << "=" << arg
		end
	    end
	    if sopt
		optstr << "   " unless optstr.empty?
		optstr << sopt
		if arg
		    optstr << "=" << arg
		end
	    end
	    puts "  " + optstr
	    puts "      " + desc.split("\n").join("\n      ")
	}
	raise Rant::RantDoneException
    end
		
    private
    def have_any_task?
	not @rantfiles.all? { |f| f.tasks.empty? }
    end

    def run_tasks
	unless have_any_task?
	    abort("No tasks defined for this rant application!")
	end
	# Target selection strategy:
	# Run tasks specified on commandline, if not given:
	# run default task, if not given:
	# run first defined task.
	target_list = @arg_targets
	# The target list is a list of strings, not Task objects!
	if target_list.empty?
	    have_default = @rantfiles.any? { |f|
		f.tasks.any? { |t| t.name == "default" }
	    }
	    if have_default
		target_list << "default"
	    else
		first = nil
		@rantfiles.each { |f|
		    unless f.tasks.empty?
			first = f.tasks.first.name
		    end
		}
		target_list << first
	    end
	end
	# Now, run all specified tasks in all rantfiles,
	# rantfiles in reverse order.
	rev_files = @rantfiles.reverse
	target_list.each { |target|
	    rev_files.each { |f|
		(f.tasks.select { |st| st.name == target }).each { |t|
		    begin
			t.run if t.needed?
		    rescue Rant::TaskFail => e
			# TODO: Report failed dependancy.
			abort("Task `#{e.message}' fail.")
		    end
		}
	    }
	}
    end

    def load_rantfiles
	# Take care: When rant isn't invoked from commandline,
	# some "rant code" could already have run!
	# We run the default Rantfiles only if no tasks where
	# already defined and no Rantfile was given in args.
	new_rf = []
	@arg_rantfiles.each { |rf|
	    if test(?f, rf)
		new_rf << rf
	    else
		abort("No such file: " + rf)
	    end
	}
	if new_rf.empty? && !have_any_task?
	    # no Rantfiles given in args, no tasks defined,
	    # so let's look for the default files
	    new_rf = rantfiles_in_dir
	end
	new_rf.map! { |path|
	    rf, is_new = rantfile_for_path(path)
	    if is_new
		load_file rf
	    end
	    rf
	}
	if @rantfiles.empty?
	    abort("No Rantfile in current directory (" + Dir.pwd + ")",
		"looking for " + Rant::RANTFILES.join(", ") +
		"; case doesn't matter.")
	end
    end

    def load_file rantfile
	msg "loading #{rantfile.path}" if verbose
	begin
	    load rantfile.path
	rescue NameError => e
	    abort("Name error when loading `#{rantfile.path}':",
	    e.message, e.backtrace)
	rescue LoadError => e
	    abort("Load error when loading `#{rantfile.path}':",
	    e.message, e.backtrace)
	rescue ScriptError => e
	    abort("Script error when loading `#{rantfile.path}':",
	    e.message, e.backtrace)
	end
	unless @rantfiles.include?(rantfile)
	    @rantfiles << rantfile
	end
    end

    # Get all rantfiles in dir.
    # If dir is nil, look in current directory.
    # Returns always an array with the pathes (not only the filenames)
    # to the rantfiles.
    def rantfiles_in_dir dir=nil
	files = []
	Dir.entries(dir || Dir.pwd).each { |entry|
	    path = (dir ? File.join(dir, entry) : entry)
	    if test(?f, path)
		Rant::RANTFILES.each { |rname|
		    if entry.downcase == rname
			files << path
			break
		    end
		}
	    end
	}
	files
    end

    def process_tasks
    end

    def process_args
	# WARNING: we currently have to fool getoptlong,
	# by temporory changing ARGV!
	# This could cause problems.
	old_argv = ARGV
	ARGV.replace(@args.dup)
	cmd_opts = GetoptLong.new(*OPTIONS.collect { |lst| lst[0..-2] })
	cmd_opts.quiet = true
	cmd_opts.each { |opt, value|
	    case opt
	    when "--verbose": more_verbose
	    when "--quiet"
		@opts[:quiet] = true
		@opts[:verbose] = false
	    when "--version"
		$stdout.puts "rant #{Rant::VERSION}"
		raise Rant::RantDoneException
	    when "--help"
		help
	    end
	}
    rescue GetoptLong::Error => e
	abort(e.message)
    ensure
	@arg_targets.concat ARGV
	ARGV.replace(old_argv)
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
	ch = Rant::Lib::parse_caller_elem(caller[2])
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
	    # TODO: Validate prerequisites?
	end
	file, is_new = rantfile_for_path(file)
	nt = yield(name, pre, block)
	nt.rantfile = file
	nt.line_number = ln
	file.tasks << nt
	nt
    end

    # Returns a Rant::Rantfile object as first value
    # and a boolean value as second. If the second is true,
    # the rantfile was created and added, otherwise the rantfile
    # already existed.
    def rantfile_for_path path
	if @rantfiles.any? { |rf| rf.path == path }
	    file = @rantfiles.find { |rf| rf.path == path }
	    [file, false]
	else
	    file = Rant::Rantfile.new(path)
	    @rantfiles << file
	    [file, true]
	end
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
                    warn_msg $!.message
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
