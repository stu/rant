
# rantlib.rb - The core of Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'getoptlong'
require 'rant/rantvar'
require 'rant/rantenv'
require 'rant/rantfile'
require 'rant/rantsys'

module Rant
    VERSION	= '0.3.1'

    # Those are the filenames for rantfiles.
    # Case matters!
    RANTFILES	= [	"Rantfile",
			"rantfile",
			"Rantfile.rb",
			"rantfile.rb",
		  ]
    
    # Names of plugins and imports for which code was loaded.
    # Files that where loaded with the `import' commant are directly
    # added; files loaded with the `plugin' command are prefixed with
    # "plugin/".
    CODE_IMPORTS = []
    
    class RantAbortException < StandardError
    end

    class RantDoneException < StandardError
    end

    class RantfileException < StandardError
    end

    # This module is a namespace for generator classes.
    module Generators
    end

end

# There is one problem with executing Rantfiles in a special context:
# In the top-level execution environment, there are some methods
# available which are not available to all objects. One example is the
# +include+ method.
#
# To (at least partially) solve this problem, we capture the `main'
# object here and delegate methods from RantContext#method_missing to
# this object.
Rant::MAIN_OBJECT = self

class Array
    def arglist
	self.shell_pathes.join(' ')
    end

    def shell_pathes
	if ::Rant::Env.on_windows?
	    self.collect { |entry|
		entry = entry.tr("/", "\\")
		if entry.include? ' '
		    '"' + entry + '"'
		else
		    entry
		end
	    }
	else
	    self.collect { |entry|
		if entry.include? ' '
		    "'" + entry + "'"
		else
		    entry
		end
	    }
	end
    end
end

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
=begin
	# commented for better performance
	meth = parts[2]
	if meth && meth =~ /\`(\w+)'/
	    meth = $1
	end
	rh[:method] = meth
=end
	rh
    end

    module_function :parse_caller_elem

    # currently unused
    class Caller
	def self.[](i)
	    new(caller[i+1])
	end
	def initialize(clr)
	    @clr = clr
	    @file = @ln = nil
	end
	def file
	    unless @file
		ca = Lib.parse_caller_elem(clr)
		@file = ca[:file]
		@ln = ca[:ln]
	    end
	    @file
	end
	def ln
	    unless @ln
		ca = Lib.parse_caller_elem(clr)
		@file = ca[:file]
		@ln = ca[:ln]
	    end
	    @ln
	end
    end
end

# The methods in this module are the public interface to Rant that can
# be used in Rantfiles.
module RantContext
    include Rant::Generators

    # Define a basic task.
    def task targ, &block
	rantapp.task(targ, &block)
    end

    # Define a file task.
    def file targ, &block
	rantapp.file(targ, &block)
    end

    # Add code and/or prerequisites to existing task.
    def enhance targ, &block
	rantapp.enhance(targ, &block)
    end

    def desc(*args)
	rantapp.desc(*args)
    end

    def gen(*args, &block)
	rantapp.gen(*args, &block)
    end

    def import(*args, &block)
	rantapp.import(*args, &block)
    end

    def plugin(*args, &block)
	rantapp.plugin(*args, &block)
    end

    # Look in the subdirectories, given by args,
    # for rantfiles.
    def subdirs *args
	rantapp.subdirs(*args)
    end

    def source rantfile
	rantapp.source(rantfile)
    end

    def sys *args
	rantapp.sys(*args)
    end
end	# module RantContext

class RantAppContext
    include Rant
    include RantContext

    def initialize(app)
	@rantapp = app
    end

    def rantapp
	@rantapp
    end

    def method_missing(sym, *args)
	# See the documentation for Rant::MAIN_OBJECT why we're doing
	# this...
	# Note also that the +send+ method also invokes private
	# methods, this is very important for our intent.
	Rant::MAIN_OBJECT.send(sym, *args)
    rescue NoMethodError
	raise NameError, "NameError: undefined local " +
	    "variable or method `#{sym}' for main:Object", caller
    end
end

module Rant
    include RantContext

    # In the class definition of Rant::RantApp, this will be set to a
    # new application object.
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
	    if @@rantapp && !@@rantapp.ran?
		@@rantapp.args.replace(args.flatten)
		@@rantapp.run
	    else
		@@rantapp = Rant::RantApp.new(args)
		@@rantapp.run
	    end
	end

	def rantapp
	    @@rantapp
	end

	def rantapp=(app)
	    @@rantapp = app
	end

	# "Clear" the current Rant application. After this call,
	# Rant has the same state as immediately after startup.
	def reset
	    @@rantapp = nil
	end
    end

    def rantapp
	@@rantapp
    end

    # Pre 0.2.7: Manually making necessary methods module
    # functions. Note that it caused problems with caller
    # parsing when the Rantfile did a `require "rant"' (irb!).
    #module_function :task, :file, :desc, :subdirs,
    #	:gen, :source, :enhance, :sys, :plugin

    extend self

end	# module Rant

class Rant::RantApp
    include Rant::Console

    # Important: We try to synchronize all tasks referenced indirectly
    # by @rantfiles with the task hash @tasks. The task hash is
    # intended for fast task lookup per task name.

    # The RantApp class has no own state.

    OPTIONS	= [
	[ "--help",	"-h",	GetoptLong::NO_ARGUMENT,
	    "Print this help and exit."				],
	[ "--version",	"-V",	GetoptLong::NO_ARGUMENT,
	    "Print version of Rant and exit."			],
	[ "--verbose",	"-v",	GetoptLong::NO_ARGUMENT,
	    "Print more messages to stderr."			],
	[ "--quiet",	"-q",	GetoptLong::NO_ARGUMENT,
	    "Don't print commands."			],
	[ "--err-commands",	GetoptLong::NO_ARGUMENT,
	    "Print failed commands and their exit status."	],
	[ "--directory","-C",	GetoptLong::REQUIRED_ARGUMENT,
	    "Run rant in DIRECTORY."				],
	[ "--rantfile",	"-f",	GetoptLong::REQUIRED_ARGUMENT,
	    "Process RANTFILE instead of standard rantfiles.\n" +
	    "Multiple files may be specified with this option"	],
	[ "--force-run","-a",	GetoptLong::REQUIRED_ARGUMENT,
	    "Force TARGET to be run, even if it isn't required.\n"],
	[ "--tasks",	"-T",	GetoptLong::NO_ARGUMENT,
	    "Show a list of all described tasks and exit."	],
	
	# "private" options intended for debugging, testing and
	# internal use. A private option is distuingished from others
	# by having +nil+ as description!

	[ "--stop-after-load",	GetoptLong::NO_ARGUMENT, nil	],
	# Print caller to $stderr on abort.
	[ "--trace-abort",	GetoptLong::NO_ARGUMENT, nil	],
    ]

    # Arguments, usually those given on commandline.
    attr_reader :args
    # A list of all Rantfiles used by this app.
    attr_reader :rantfiles
    # A list of target names to be forced (run even
    # if not required). Each of these targets will be removed
    # from this list after the first run.
    #
    # Forced targets will be run before other targets.
    attr_reader :force_targets
    # A list of all registered plugins.
    attr_reader :plugins
    # The context in which Rantfiles are loaded. RantContext methods
    # may be called through an instance_eval on this object (e.g. from
    # plugins).
    attr_reader :context
    # The [] and []= operators may be used to set/get values from this
    # object (like a hash). It is intended to let the different
    # modules, plugins and tasks to communicate to each other.
    attr_reader :var
    # A hash with all tasks. For fast task lookup use this hash with
    # the taskname as key.
    attr_reader :tasks
    # A list with of all imports (code loaded with +import+).
    attr_reader :imports

    def initialize *args
	@args = args.flatten
	# Rantfiles will be loaded in the context of this object.
	@context = RantAppContext.new(self)
	@sys = ::Rant::SysObject.new(self)
	Rant.rantapp ||= self
	@rantfiles = []
	@tasks = {}
	@opts = {
	    :verbose	=> 0,
	    :quiet	=> false,
	}
	@arg_rantfiles = []	# rantfiles given in args
	@arg_targets = []	# targets given in args
	@force_targets = []
	@ran = false
	@done = false
	@plugins = []
	@var = Rant::RantVar::Space.new
	@imports = []

	@task_show = nil
	@task_desc = nil

	@orig_pwd = nil

    end

    # Just ensure that Rant.rantapp holds an RantApp after loading
    # this file. The code in initialize will register the new app with
    # Rant.rantapp= if necessary.
    self.new

    def [](opt)
	@opts[opt]
    end

    def []=(opt, val)
	case opt
	when :directory
	    self.rootdir = val
	else
	    @opts[opt] = val
	end
    end

    def rootdir
	@opts[:directory].dup
    end

    def rootdir=(newdir)
	if @ran
	    raise "rootdir of rant application can't " +
		"be changed after calling `run'"
	end
	@opts[:directory] = newdir.dup
	rootdir	# return a dup of the new rootdir
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
	# remind pwd
	@orig_pwd = Dir.pwd
	# Process commandline.
	process_args
	# Set pwd.
	opts_dir = @opts[:directory]
	if opts_dir
	    unless test(?d, opts_dir)
		abort("No such directory - #{opts_dir}")
	    end
	    opts_dir != @orig_pwd && Dir.chdir(opts_dir)
	else
	    @opts[:directory] = @orig_pwd
	end
	# read rantfiles
	load_rantfiles

	raise Rant::RantDoneException if @opts[:stop_after_load]

	# Notify plugins before running tasks
	@plugins.each { |plugin| plugin.rant_start }
	if @opts[:targets]
	    show_descriptions
	    raise Rant::RantDoneException
	end
	# run tasks
	run_tasks
	raise Rant::RantDoneException
    rescue Rant::RantDoneException
	@done = true
	# Notify plugins
	@plugins.each { |plugin| plugin.rant_done }
	return 0
    rescue Rant::RantfileException
	err_msg "Invalid Rantfile: " + $!.message
	$stderr.puts "rant aborted!"
	return 1
    rescue Rant::RantAbortException
	$stderr.puts "rant aborted!"
	return 1
    rescue
	err_msg $!.message, $!.backtrace
	$stderr.puts "rant aborted!"
	return 1
    ensure
	# TODO: exception handling!
	@plugins.each { |plugin| plugin.rant_plugin_stop }
	@plugins.each { |plugin| plugin.rant_quit }
	# restore pwd
	Dir.pwd != @orig_pwd && Dir.chdir(@orig_pwd)
	Rant.rantapp = self.class.new
    end

    ###### methods accessible through RantContext ####################
    def show *args
	@task_show = *args.join("\n")
    end

    def desc *args
	if args.empty? || (args.size == 1 && args.first.nil?)
	    @task_desc = nil
	else
	    @task_desc = args.join("\n")
	end
    end

    def task targ, &block
	prepare_task(targ, block) { |name,pre,blk|
	    Rant::Task.new(self, name, pre, &blk)
	}
    end

    def file targ, &block
	prepare_task(targ, block) { |name,pre,blk|
	    Rant::FileTask.new(self, name, pre, &blk)
	}
    end

    def gen(*args, &block)
	# retrieve caller info
	clr = caller[1]
	ch = Rant::Lib::parse_caller_elem(clr)
	name = nil
	pre = []
	ln = ch[:ln] || 0
	file = ch[:file]
	# validate args
	generator = args.shift
	# Let modules/classes from the Generator namespace override
	# other generators.
	begin
	    if generator.is_a? Module
		generator = ::Rant::Generators.const_get(generator.to_s)
	    end
	rescue NameError, ArgumentError
	end
	unless generator.respond_to? :rant_generate
	    abort(pos_text(file, ln),
		"First argument to `gen' has to be a task-generator.")
	end
	# ask generator to produce a task for this application
	generator.rant_generate(self, ch, args, &block)
    end

    # Currently ignores block.
    def import(*args, &block)
	if block
	    warn_msg "import: currently ignoring block"
	end
	args.flatten.each { |arg|
	    unless String === arg
		abort("import: currently " + 
		    "only strings are allowed as arguments")
	    end
	    unless @imports.include? arg
		unless Rant::CODE_IMPORTS.include? arg
		    begin
			require "rant/import/#{arg}"
		    rescue LoadError => e
			abort("No such import - #{arg}")
		    end
		    Rant::CODE_IMPORTS << arg.dup
		end
		@imports << arg.dup
	    end
	}
    end

    def plugin(*args, &block)
	# retrieve caller info
	clr = caller[1]
	ch = Rant::Lib::parse_caller_elem(clr)
	name = nil
	pre = []
	ln = ch[:ln] || 0
	file = ch[:file]

	pl_name = args.shift
	pl_name = pl_name.to_str if pl_name.respond_to? :to_str
	pl_name = pl_name.to_s if pl_name.is_a? Symbol
	unless pl_name.is_a? String
	    abort(pos_text(file, ln),
		"Plugin name has to be a string or symbol.")
	end
	lc_pl_name = pl_name.downcase
	import_name = "plugin/#{lc_pl_name}"
	unless Rant::CODE_IMPORTS.include? import_name
	    begin
		require "rant/plugin/#{lc_pl_name}"
		Rant::CODE_IMPORTS << import_name
	    rescue LoadError
		abort(pos_text(file, ln),
		    "no such plugin library - `#{lc_pl_name}'")
	    end
	end
	pl_class = nil
	begin
	    pl_class = ::Rant::Plugin.const_get(pl_name)
	rescue NameError, ArgumentError
	    abort(pos_text(file, ln),
		"`#{pl_name}': no such plugin")
	end

	plugin = pl_class.rant_plugin_new(self, ch, *args, &block)
	# TODO: check for rant_plugin?
	@plugins << plugin
	msg 2, "Plugin `#{plugin.rant_plugin_name}' registered."
	plugin.rant_plugin_init
	# return plugin instance
	plugin
    end

    # Add block and prerequisites to the task specified by the
    # name given as only key in targ.
    # If there is no task with the given name, generate a warning
    # and a new file task.
    def enhance targ, &block
	prepare_task(targ, block) { |name,pre,blk|
	    t = @tasks[name]
	    if Rant::MetaTask === t
		t = t.last
	    end
	    if t
		unless t.respond_to? :enhance
		    abort("Can't enhance task `#{name}'")
		end
		t.enhance(pre, &blk)
		return t
	    end
	    warn_msg "enhance \"#{name}\": no such task",
		"Generating a new file task with the given name."
	    Rant::FileTask.new(self, name, pre, &blk)
	}
    end

    def source rantfile
	rf, is_new = rantfile_for_path(rantfile)
	return false unless is_new
	unless rf.exist?
	    abort("source: No such file to load - #{rantfile}")
	end
	load_file rf
	true
    end

    # Search the given directories for Rantfiles.
    def subdirs *args
	args.flatten!
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

    def sys(*args)
	if args.empty?
	    @sys
	else
	    @sys.sh(*args)
	end
    end
    ##################################################################

    # Pop (remove and return) current pending task description.
    def pop_desc
	td = @task_desc
	@task_desc = nil
	td
    end

    # Prints msg as error message and raises a RantAbortException.
    def abort *msg
	err_msg(msg) unless msg.empty?
	$stderr.puts caller if @opts[:trace_abort]
	raise Rant::RantAbortException
    end

    def help
	puts "rant [-f RANTFILE] [OPTIONS] tasks..."
	puts
	puts "Options are:"
	print option_listing(OPTIONS)
	raise Rant::RantDoneException
    end

    def show_descriptions
	tlist = select_tasks { |t| t.description }
	if tlist.empty?
	    msg "No described targets."
	    return
	end
	prefix = "rant "
	infix = "  # "
	name_length = 0
	tlist.each { |t|
	    if t.name.length > name_length
		name_length = t.name.length
	    end
	}
	name_length < 7 && name_length = 7
	cmd_length = prefix.length + name_length
	tlist.each { |t|
	    print(prefix + t.name.ljust(name_length) + infix)
	    dt = t.description.sub(/\s+$/, "")
	    puts dt.sub("\n", "\n" + ' ' * cmd_length + infix + "  ")
	}
	true
    end
		
    # Increase verbosity.
    def more_verbose
	@opts[:verbose] += 1
	@opts[:quiet] = false
    end
    
    # This is actually an integer indicating the verbosity level.
    # Usual values range from 0 to 3.
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

    def msg *args
	verbose_level = args[0]
	if verbose_level.is_a? Integer
	    super(args[1..-1]) if verbose_level <= verbose
	else
	    super
	end
    end

    # Print a command message as would be done from a call to a
    # Sys method.
    def cmd_msg cmd
	$stdout.puts cmd unless quiet?
    end

    ###### public methods regarding plugins ##########################
    # The preferred way for a plugin to report a warning.
    def plugin_warn(*args)
	warn_msg(*args)
    end
    # The preferred way for a plugin to report an error.
    def plugin_err(*args)
	err_msg(*args)
    end

    # Get the plugin with the given name or nil. Yields the plugin
    # object if block given.
    def plugin_named(name)
	@plugins.each { |plugin|
	    if plugin.rant_plugin_name == name
		yield plugin if block_given?
		return plugin
	    end
	}
	nil
    end
    ##################################################################

    # All targets given on commandline, including those given
    # with the -a option. The list will be in processing order.
    def cmd_targets
	@force_targets + @arg_targets
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
	target_list = @force_targets + @arg_targets
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
			break
		    end
		}
		target_list << first
	    end
	end
	# Now, run all specified tasks in all rantfiles,
	# rantfiles in reverse order.
	opt = {}
	matching_tasks = 0
	target_list.each do |target|
	    matching_tasks = 0
	    if @force_targets.include?(target)
		opt[:force] = true
		@force_targets.delete(target)
	    end
	    (select_tasks { |t| t.name == target }).each { |t|
		matching_tasks += 1
		begin
		    t.invoke(opt)
		rescue Rant::TaskFail => e
		    # TODO: Report failed dependancy.
		    abort("Task `#{e.tname}' fail.")
		end
	    }
	    if matching_tasks == 0
		abort("Don't know how to build `#{target}'.")
	    end
	end
    end

    # Returns a list with all tasks for which yield
    # returns true.
    def select_tasks
	selection = []
	### pre 0.2.10 ##################
	# @rantfile.reverse.each { |rf|
	#################################
	@rantfiles.each { |rf|
	    rf.tasks.each { |t|
		selection << t if yield t
	    }
	}
	selection
    end
    public :select_tasks

    # Returns an array (might be a MetaTask) with all tasks that have
    # the given name.
    def select_tasks_by_name name
	s = @tasks[name]
	case s
	when nil: []
	when Rant::Worker: [s]
	else # assuming MetaTask
	    s
	end
    end
    public :select_tasks_by_name

    # Get the first task for which yield returns true. Returns nil if
    # yield never returned true.
    def select_task
	@rantfiles.reverse.each { |rf|
	    rf.tasks.each { |t|
		return t if yield t
	    }
	}
	nil
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
		"; case matters!")
	end
    end

    def load_file rantfile
	msg 1, "source #{rantfile.path}"
	begin
	    path = rantfile.absolute_path
	    @context.instance_eval(File.read(path), path)
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
    private :load_file

    # Get all rantfiles in dir.
    # If dir is nil, look in current directory.
    # Returns always an array with the pathes (not only the filenames)
    # to the rantfiles.
    def rantfiles_in_dir dir=nil
	files = []
	::Rant::RANTFILES.each { |rfn|
	    path = dir ? File.join(dir, rfn) : rfn
	    # We load don't accept rantfiles with pathes that differ
	    # only in case. This protects from loading the same file
	    # twice on case insensitive file systems.
	    unless files.find { |f| f.downcase == path.downcase }
		files << path if test(?f, path)
	    end
	}
	files
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
	    when "--verbose": more_verbose
	    when "--quiet"
		@opts[:quiet] = true
		@opts[:verbose] = -1
	    when "--err-commands"
		@opts[:err_commands] = true
	    when "--version"
		$stdout.puts "rant #{Rant::VERSION}"
		raise Rant::RantDoneException
	    when "--help"
		help
	    when "--directory"
		@opts[:directory] = value
	    when "--rantfile"
		@arg_rantfiles << value
	    when "--force-run"
		@force_targets << value
	    when "--tasks"
		@opts[:targets] = true
	    when "--stop-after-load"
		@opts[:stop_after_load] = true
	    when "--trace-abort"
		@opts[:trace_abort] = true
	    end
	}
    rescue GetoptLong::Error => e
	abort(e.message)
    ensure
	rem_args = ARGV.dup
	ARGV.replace(old_argv)
	rem_args.each { |ra|
	    if ra =~ /(^[^=]+)=([^=]+)$/
		msg 2, "Environment: #$1=#$2"
		ENV[$1] = $2
	    else
		@arg_targets << ra
	    end
	}
    end

    def prepare_task(targ, block, clr = caller[2])

	# Allow override of caller, usefull for plugins and libraries
	# that define tasks.
	if targ.is_a? Hash
	    targ.reject! { |k, v|
		case k
		when :__caller__
		    clr = v
		    true
		else
		    false
		end
	    }
	end
	cinf = Hash === clr ? clr : Rant::Lib::parse_caller_elem(clr)

	name, pre, file, ln = normalize_task_arg(targ, cinf)

	file, is_new = rantfile_for_path(file)
	nt = yield(name, pre, block)
	nt.rantfile = file
	nt.line_number = ln
	nt.description = @task_desc
	@task_desc = nil
	file.tasks << nt
	hash_task nt
	nt
    end
    public :prepare_task

    def hash_task task
	n = task.name
	et = @tasks[n]
	case et
	when nil
	    @tasks[n] = task
	when Rant::Worker
	    mt = Rant::MetaTask.new n
	    mt << et << task
	    @tasks[n] = mt
	else # assuming  Rant::MetaTask
	    et << task
	end
    end

    # Tries to extract task name and prerequisites from the typical
    # argument to the +task+ command. +targ+ should be one of String,
    # Symbol or Hash. clr is the caller and is used for error
    # reporting and debugging.
    #
    # Returns four values, the first is a string which is the task name
    # and the second is an array with the prerequisites.
    # The third is the file name of +clr+, the fourth is the line number
    # of +clr+.
    def normalize_task_arg(targ, clr)
	# TODO: check the code calling this method so that we can
	# assume clr is already a hash
	ch = Hash === clr ? clr : Rant::Lib::parse_caller_elem(clr)
	name = nil
	pre = []
	ln = ch[:ln] || 0
	file = ch[:file]
	
	# process and validate targ
	if targ.is_a? Hash
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
		name = normalize_task_name(k, file, ln)
		pre = v
	    }
	    if pre.respond_to? :to_ary
		pre = pre.to_ary.dup
		pre.map! { |elem|
		    normalize_task_name(elem, file, ln)
		}
	    else
		pre = [normalize_task_name(pre, file, ln)]
	    end
	else
	    name = normalize_task_name(targ, file, ln)
	end

	[name, pre, file, ln]
    end
    public :normalize_task_arg

    # Tries to make a task name out of arg and returns
    # the valid task name. If not possible, calls abort
    # with an appropriate error message using file and ln.
    def normalize_task_name(arg, file, ln)
	return arg if arg.is_a? String
	if Symbol === arg
	    arg.to_s
	elsif arg.respond_to? :to_str
	    arg.to_str
	else
	    abort(pos_text(file, ln),
		"Task name has to be a string or symbol.")
	end
    end

    # Returns a Rant::Rantfile object as first value
    # and a boolean value as second. If the second is true,
    # the rantfile was created and added, otherwise the rantfile
    # already existed.
    def rantfile_for_path path
	# TODO: optimization: File.expand_path is called very often
	# (don't forget the calls from Rant::Path#absolute_path)
	abs_path = File.expand_path(path)
	if @rantfiles.any? { |rf| rf.absolute_path == abs_path }
	    file = @rantfiles.find { |rf| rf.absolute_path == abs_path }
	    [file, false]
	else
	    file = Rant::Rantfile.new(abs_path, abs_path)
	    @rantfiles << file
	    [file, true]
	end
    end

end	# class Rant::RantApp
