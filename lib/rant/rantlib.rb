
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

# There is one problem with executing Rantfiles in a special context:
# In the top-level execution environment, there are some methods
# available which are not available to all objects. One example is the
# +include+ method.
#
# To (at least partially) solve this problem, we capture the `main'
# object here and delegate methods from RantContext#method_missing to
# this object.
Rant::MAIN_OBJECT = self

unless Process::Status.method_defined?(:success?)
    class Process::Status
        def success?;  exitstatus == 0; end
    end
end
if RUBY_VERSION < "1.8.2"
    class Array
        def flatten
            cp = self.dup
            cp.flatten!
            cp
        end
        def flatten!
            res = []
            flattened = false
            self.each { |e|
                if e.respond_to? :to_ary
                    res.concat(e.to_ary)
                    flattened = true
                else
                    res << e
                end
            }
            if flattened
                replace(res)
                flatten!
                self
            end
        end
    end
end

class Array

    # Concatenates all elements like #join(' ') but also puts quotes
    # around strings that contain a space.
    def arglist
	self.shell_pathes.join(' ')
    end

    def shell_pathes
	entry = nil
	if ::Rant::Env.on_windows?
	    self.collect { |entry|
		entry = entry.to_s.tr("/", "\\")
		if entry.include? ' '
		    '"' + entry + '"'
		else
		    entry
		end
	    }
	else
	    self.collect { |entry|
		entry = entry.to_s
		if entry.include? ' '
		    "'" + entry + "'"
		else
		    entry
		end
	    }
	end
    end
end

class String
    def sub_ext(ext, new_ext = nil)
	if new_ext
	    self.sub(/#{Regexp.escape ext}$/, new_ext)
	else
	    self.sub(/(\.[^.]*$)|$/, ".#{ext}")
	end
    end
    def to_rant_target
        self
    end
end

module Rant::Lib

    # Parses one string (elem) as it occurs in the array
    # which is returned by caller.
    # E.g.:
    #	p parse_caller_elem "/usr/local/lib/ruby/1.8/irb/workspace.rb:52:in `irb_binding'"
    # prints:
    #   {:ln=>52, :file=>"/usr/local/lib/ruby/1.8/irb/workspace.rb"} 
    #
    # Note: This method splits on the pattern <tt>:(\d+)(:|$)</tt>,
    # assuming anything before is the filename.
    def parse_caller_elem(elem)
	return { :file => "", :ln => 0 } if elem.nil?
	if elem =~ /^(.+):(\d+)(:|$)/
	    { :file => $1, :ln => $2.to_i }
	else
	    # should never occur
	    $stderr.puts "parse_caller_elem: #{elem.inspect}"
	    { :file => elem, :ln => 0 }
	end
	
	#parts = elem.split(":")
	#{ :file => parts[0], :ln => parts[1].to_i }
    end
    module_function :parse_caller_elem

end

# The methods in this module are the public interface to Rant that can
# be used in Rantfiles.
module RantContext
    include Rant::Generators

    Env = Rant::Env
    FileList = Rant::FileList

    # Define a basic task.
    def task(targ, &block)
	rac.task(targ, &block)
    end

    # Define a file task.
    def file(targ, &block)
	rac.file(targ, &block)
    end

    # Add code and/or prerequisites to existing task.
    def enhance(targ, &block)
	rac.enhance(targ, &block)
    end

    def desc(*args)
	rac.desc(*args)
    end

    def gen(*args, &block)
	rac.gen(*args, &block)
    end

    def import(*args, &block)
	rac.import(*args, &block)
    end

    def plugin(*args, &block)
	rac.plugin(*args, &block)
    end

    # Look in the subdirectories, given by args,
    # for rantfiles.
    def subdirs(*args)
	rac.subdirs(*args)
    end

    def source(opt, rantfile = nil)
	rac.source(opt, rantfile)
    end

    def sys(*args, &block)
	rac.sys(*args)
    end

    def var(*args, &block)
	rac.var(*args, &block)
    end

    def make(*args, &block)
        rac.make(*args, &block)
    end
end	# module RantContext

class RantAppContext
    include RantContext

    def initialize(app)
	@rac = app
    end

    # +rac+ stands for "rant compiler"
    def rac
	@rac
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

    # In the class definition of Rant::RantApp, this will be set to a
    # new application object.
    @@rac = nil

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
	    if @@rac && !@@rac.run?
		@@rac.args.replace(args.flatten)
		@@rac.run
	    else
		@@rac = Rant::RantApp.new
		@@rac.run(args)
	    end
	end

	def rac
	    @@rac
	end

	def rac=(app)
	    @@rac = app
	end
    end

end	# module Rant

class Rant::RantApp
    include Rant::Console

    # Important: We try to synchronize all tasks referenced indirectly
    # by @rantfiles with the task hash @tasks. The task hash is
    # intended for fast task lookup per task name.
    #
    # All tasks are registered to the system by the +prepare_task+
    # method.

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

    # Reference project's root directory in task names by preceding
    # them with this character.
    ROOT_DIR_ID = "#"
    ESCAPE_ID = "\\"

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
    # may be called through this object (e.g. from plugins).
    attr_reader :context
    alias cx context
    # A hash with all tasks. For fast task lookup use this hash with
    # the taskname as key.
    #
    # See also: #resolve, #make
    attr_reader :tasks
    # A list of all imports (code loaded with +import+).
    attr_reader :imports
    # Current subdirectory relative to project's root directory
    # (#rootdir).
    attr_reader :current_subdir
    # List of proc objects used to automatically create required
    # tasks. (Especially used for Rules.)
    #
    # Note: Might change before 1.0
    attr_reader :resolve_hooks

    def initialize(*args)
	unless args.empty?
	    STDERR.puts caller[0]
	    STDERR.puts "Warning: Giving arguments Rant::RantApp.new " +
		"is deprecated. Give them to the #run method."
	end
	@args = args.flatten
	# Rantfiles will be loaded in the context of this object.
	@context = RantAppContext.new(self)
	@sys = ::Rant::SysObject.new(self)
	Rant.rac ||= self
	@rantfiles = []
	@tasks = {}
	@opts = {
	    :verbose	=> 0,
	    :quiet	=> false,
	    :directory	=> "",
	}
	@arg_rantfiles = []	# rantfiles given in args
	@arg_targets = []	# targets given in args
	@force_targets = []
	@run = false
	@done = false
	@plugins = []
	@var = Rant::RantVar::Space.new
	@var.query :ignore, :AutoList, []
	@imports = []

	#@task_show = nil
	@task_desc = nil

	@orig_pwd = nil
	@current_subdir = ""
	@resolve_hooks = []
    end

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
	@opts[:directory]
    end

    def rootdir=(newdir)
	if @run
	    raise "rootdir of rant application can't " +
		"be changed after calling `run'"
	end
	unless String === newdir
	    raise "rootdir has to be a String"
	end
	@opts[:directory] = newdir.dup
    end

    ### support for subdirectories ###################################
    def expand_project_path(path)
	expand_path(@current_subdir, path)
    end
    def expand_path(subdir, path)
	case path
	when nil:	subdir.dup
	when "":	subdir.dup
	when /^#/:	path.sub(/^#/, '')
	when /^\\#/:	path.sub(/^\\/, '')
	else
	    #puts "epp: current_subdir: #@current_subdir"
	    if subdir.empty?
		# we are in project's root directory
		path
	    else
		File.join(subdir, path)
	    end
	end
    end
    # Returns an absolute path. If path resolves to a directory this
    # method ensures that the returned absolute path doesn't end in a
    # slash.
    def project_to_fs_path(path)
	base = rootdir.empty? ? Dir.pwd : rootdir
	sub = expand_project_path(path)
	sub.empty? ? base : File.join(base, sub)
    end
    def goto(dir)
	# TODO: optimize
	p_dir = expand_project_path(dir)
	base = rootdir.empty? ? Dir.pwd : rootdir
	abs_path = p_dir.empty? ? base : File.join(base, p_dir)
	@current_subdir = p_dir
	unless Dir.pwd == abs_path
	    #puts "pwd: #{Dir.pwd}; abs_path: #{abs_path}"
	    #puts "   current subdir: #@current_subdir"
	    Dir.chdir abs_path
	    msg 1, "in #{abs_path}"
	    #STDERR.puts "rant: in #{p_dir}"
	end
    end
    # +dir+ is a path relative to +rootdir+
    def goto_project_dir(dir)
	# TODO: optimize
	goto "##{dir}"
    end
    # Execute the give block in project directory dir.
    def in_project_dir(dir)
	prev_subdir = @current_subdir
	goto_project_dir(dir)
	yield
    ensure
	goto_project_dir(prev_subdir)
    end
    ##################################################################

    def run?
	@run
    end

    def done?
	@done
    end

    # Returns 0 on success and 1 on failure.
    def run(*args)
	@run = true
	@args.concat(args.flatten)
	# remind pwd
	@orig_pwd = Dir.pwd
	# Process commandline.
	process_args
	# Set pwd.
	opts_dir = @opts[:directory]
	if !(opts_dir.empty? || opts_dir.nil?)
	    opts_dir = File.expand_path(opts_dir)
	    unless test(?d, opts_dir)
		abort("No such directory - #{opts_dir}")
	    end
	    Dir.chdir(opts_dir) if opts_dir != @orig_pwd
	    @opts[:directory] = opts_dir
	else
	    @opts[:directory] = @orig_pwd
	end
	# read rantfiles
	load_rantfiles

	raise Rant::RantDoneException if @opts[:stop_after_load]

	# Notify plugins before running tasks
	@plugins.each { |plugin| plugin.rant_start }
	if @opts[:tasks]
	    show_descriptions
	    raise Rant::RantDoneException
	end
	# run tasks
	run_tasks
	goto "#"
	raise Rant::RantDoneException
    rescue Rant::RantDoneException
	@done = true
	# Notify plugins
	goto "#"
	@plugins.each { |plugin| plugin.rant_done }
	return 0
    rescue Rant::RantError
	ch = get_ch_from_backtrace($!.backtrace)
	if ch
	    err_msg(pos_text(ch[:file], ch[:ln]), $!.message)
	else
	    err_msg $!.message, $!.backtrace[0..4]
	end
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
	Rant.rac = self.class.new
    end

    ###### methods accessible through RantContext ####################

    def desc(*args)
	if args.empty? || (args.size == 1 && args.first.nil?)
	    @task_desc = nil
	else
	    @task_desc = args.join("\n")
	end
    end

    def task(targ, &block)
	prepare_task(targ, block) { |name,pre,blk|
	    Rant::Task.new(self, name, pre, &blk)
	}
    end

    def file(targ, &block)
	prepare_task(targ, block) { |name,pre,blk|
	    Rant::FileTask.new(self, name, pre, &blk)
	}
    end

    def gen(*args, &block)
	# retrieve caller info
	ch = Rant::Lib::parse_caller_elem(caller[1])
	# validate args
	generator = args.shift
	unless generator.respond_to? :rant_gen
	    abort_at(ch,
		"gen: First argument to has to be a task-generator.")
	end
	# ask generator to produce a task for this application
	generator.rant_gen(self, ch, args, &block)
    end

    # Currently ignores block.
    def import(*args, &block)
	ch = Rant::Lib::parse_caller_elem(caller[1])
	if block
	    warn_msg pos_text(ch[:file], ch[:ln]),
		"import: ignoring block"
	end
	args.flatten.each { |arg|
	    unless String === arg
                abort_at(ch, "import: only strings allowed as arguments")
	    end
	    unless @imports.include? arg
		unless Rant::CODE_IMPORTS.include? arg
		    begin
			msg 2, "import #{arg}"
			require "rant/import/#{arg}"
		    rescue LoadError => e
			abort_at(ch, "No such import - #{arg}")
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
		    "no such plugin library -- #{lc_pl_name}")
	    end
	end
	pl_class = nil
	begin
	    pl_class = ::Rant::Plugin.const_get(pl_name)
	rescue NameError, ArgumentError
	    abort(pos_text(file, ln),
		"no such plugin -- #{pl_name}")
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
    def enhance(targ, &block)
	prepare_task(targ, block) { |name,pre,blk|
	    t = resolve(name).last
	    if t
		unless t.respond_to? :enhance
		    abort("Can't enhance task `#{name}'")
		end
		t.enhance(pre, &blk)
		# Important: return from method, don't break to
		# prepare_task which would add task t again
		return t
	    end
	    warn_msg "enhance \"#{name}\": no such task",
		"Generating a new file task with the given name."
	    Rant::FileTask.new(self, name, pre, &blk)
	}
    end

    # Returns the value of the last expression executed in +rantfile+.
    def source(opt, rantfile = nil)
	unless rantfile
	    rantfile = opt
	    opt = nil
	end
	make_rf = opt != :n && opt != :now
	rf, is_new = rantfile_for_path(rantfile)
	return false unless is_new
	make rantfile if make_rf
	unless File.exist? rf.path
	    abort("source: No such file -- #{rantfile}")
	end

	load_file rf
    end

    # Search the given directories for Rantfiles.
    def subdirs(*args)
	args.flatten!
	ch = Rant::Lib::parse_caller_elem(caller[1])
	args.each { |arg|
	    if arg.respond_to? :to_str
		arg = arg.to_str
	    else
		abort_at(ch, "subdirs: arguments must be strings")
	    end
	    loaded = false
	    prev_subdir = @current_subdir
	    begin
		#puts "* subdir *",
		#    "  rootdir:        #{rootdir}",
		#    "  current subdir: #@current_subdir",
		#    "  pwd:            #{Dir.pwd}",
		#    "  arg:            #{arg}"
		goto arg
		rantfiles_in_dir.each { |f|
		    loaded = true
		    rf, is_new = rantfile_for_path(f)
		    load_file rf if is_new
		}
	    ensure
		#puts "  going back to project dir: #{prev_subdir}"
		goto_project_dir prev_subdir
	    end
	    unless loaded || @opts[:no_warn_subdir]
		warn_msg(pos_text(ch[:file], ch[:ln]),
		    "subdirs: No Rantfile in subdir `#{arg}'.")
	    end
	}
    rescue SystemCallError => e
	abort_at(ch, "subdirs: " + e.message)
    end

    def sys(*args, &block)
	args.empty? ? @sys : @sys.sh(*args)
    end

    # The [] and []= operators may be used to set/get values from this
    # object (like a hash). It is intended to let the different
    # modules, plugins and tasks to communicate with each other.
    def var(*args, &block)
	args.empty? ? @var : @var.query(*args, &block)
    end
    ##################################################################

    # Pop (remove and return) current pending task description.
    def pop_desc
	td = @task_desc
	@task_desc = nil
	td
    end

    # Prints msg as error message and raises an RantAbortException.
    def abort(*msg)
	err_msg(msg) unless msg.empty?
	$stderr.puts caller if @opts[:trace_abort]
	raise Rant::RantAbortException
    end

    def abort_at(ch, *msg)
	err_msg(pos_text(ch[:file], ch[:ln]), msg)
	$stderr.puts caller if @opts[:trace_abort]
	raise Rant::RantAbortException
    end

    def show_help
	puts "rant [-f RANTFILE] [OPTIONS] tasks..."
	puts
	puts "Options are:"
	print option_listing(OPTIONS)
    end

    def show_descriptions
	tlist = select_tasks { |t| t.description }
	# +target_list+ aborts if no task defined, so we can be sure
	# that +default+ is not nil
	def_target = target_list.first
	if tlist.empty?
	    puts "rant         # => " + list_task_names(
		resolve(def_target)).join(', ')
	    msg "No described tasks."
	    return
	end
	prefix = "rant "
	infix = "  # "
	name_length = 0
	tlist.each { |t|
	    if t.full_name.length > name_length
		name_length = t.full_name.length
	    end
	}
	name_length < 7 && name_length = 7
	cmd_length = prefix.length + name_length
	unless tlist.first.full_name == def_target
	    defaults = list_task_names(
		resolve(def_target)).join(', ')
	    puts "#{prefix}#{' ' * name_length}#{infix}=> #{defaults}"
	end
	tlist.each { |t|
	    print(prefix + t.full_name.ljust(name_length) + infix)
	    dt = t.description.sub(/\s+$/, "")
	    puts dt.sub(/\n/, "\n" + ' ' * cmd_length + infix + "  ")
	}
	true
    end
    def list_task_names(*tasks)
	rsl = []
	tasks.flatten.each { |t|
	    if t.respond_to?(:has_actions?) && t.has_actions?
		rsl << t
	    elsif t.respond_to? :prerequisites
		if t.prerequisites.empty?
		    rsl << t
		else
		    rsl.concat(list_task_names(t.prerequisites))
		end
	    else
		rsl << t
	    end
	}
	rsl
    end
    private :list_task_names

    # This is actually an integer indicating the verbosity level.
    # Usual values range from 0 to 3.
    def verbose
	@opts[:verbose]
    end

    def quiet?
	@opts[:quiet]
    end

    def pos_text(file, ln)
	t = "in file `#{file}'"
        t << ", line #{ln}" if ln && ln > 0
	t << ": "
    end

    def msg(*args)
	verbose_level = args[0]
	if verbose_level.is_a? Integer
	    super(args[1..-1]) if verbose_level <= verbose
	else
	    super
	end
    end

    # Print a command message as would be done from a call to a
    # Sys method.
    def cmd_msg(cmd)
	puts cmd unless quiet?
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
        !@tasks.empty?
    end

    def target_list
	if !have_any_task? && @resolve_hooks.empty?
	    abort("No tasks defined for this rant application!")
	end

	# Target selection strategy:
	# Run tasks specified on commandline, if not given:
	# run default task, if not given:
	# run first defined task.
	target_list = @force_targets + @arg_targets
	# The target list is a list of strings, not Task objects!
	if target_list.empty?
	    def_tasks = resolve "default"
	    unless def_tasks.empty?
		target_list << "default"
	    else
		@rantfiles.each { |f|
		    unless f.tasks.empty?
			target_list << f.tasks.first.full_name
			break
		    end
		}
	    end
	end
	target_list
    end

    def run_tasks
	# Now, run all specified tasks in all rantfiles,
	# rantfiles in reverse order.
	opt = {}
	matching_tasks = 0
	target_list.each do |target|
	    goto "#"
	    if make(target) == 0
		abort("Don't know how to make `#{target}'.")
	    end
	end
    end

    def make(target, *args, &block)
        ch = nil
        if target.respond_to? :to_hash
            targ = target.to_hash
            ch = Rant::Lib.parse_caller_elem(caller[1])
            abort_at(ch, "make: too many arguments") unless args.empty?
            tn = nil
            prepare_task(targ, block, ch) { |name,pre,blk|
                tn = name
                Rant::FileTask.new(self, name, pre, &blk)
            }
            build(tn)
        elsif target.respond_to? :to_rant_target
            rt = target.to_rant_target
            opt = args.shift
            unless args.empty?
                ch ||= Rant::Lib.parse_caller_elem(caller[1])
                abort_at(ch, "make: too many arguments")
            end
            if block
                # create a file task
                ch ||= Rant::Lib.parse_caller_elem(caller[1])
                prepare_task(rt, block, ch) { |name,pre,blk|
                    Rant::FileTask.new(self, name, pre, &blk)
                }
                build(rt)
            else
                build(rt, opt||{})
            end
        elsif target.respond_to? :rant_gen
            ch = Rant::Lib.parse_caller_elem(caller[1])
            rv = target.rant_gen(self, ch, args, &block)
            unless rv.respond_to? :to_rant_target
                abort_at(ch, "make: invalid generator return value")
            end
            build(rv.to_rant_target)
            rv
        else
            ch = Rant::Lib.parse_caller_elem(caller[1])
            abort_at(ch,
                "make: generator or target as first argument required.")
        end
    end
    public :make

    # Invoke all tasks necessary to build +target+. Returns the number
    # of tasks invoked.
    def build(target, opt = {})
	opt[:force] = true if @force_targets.delete(target)
	matching_tasks = 0
	old_subdir = @current_subdir
	old_pwd = Dir.pwd
	resolve(target).each { |t|
	    matching_tasks += 1
	    begin
		t.invoke(opt)
	    rescue Rant::TaskFail => e
		err_task_fail(e)
		abort
	    end
	}
	@current_subdir = old_subdir
	Dir.chdir old_pwd
	matching_tasks
    end
    public :build

    # Currently always returns an array (which might actually be an
    # empty array, but never nil).
    def resolve(task_name, rel_project_dir = @current_subdir)
	s = @tasks[expand_path(rel_project_dir, task_name)]
	case s
	when nil
	    @resolve_hooks.each { |s|
		# Note: will probably change to get more params
		s = s[task_name]
                #if s
                #    puts s.size
                #    t = s.first
                #    puts t.full_name
                #    puts t.name
                #    puts t.deps
                #end
		return s if s
	    }
	    []
	when Rant::Node: [s]
	else # assuming list of tasks
	    s
	end
    end
    public :resolve

    # This hook will be invoked when no matching task is found for a
    # target. It may create one or more tasks for the target, which is
    # given as argument, on the fly and return an array of the created
    # tasks or nil.
    def at_resolve(&block)
	@resolve_hooks << block if block
    end
    public :at_resolve

    # Returns a list with all tasks for which yield
    # returns true.
    def select_tasks
	selection = []
	@rantfiles.each { |rf|
	    rf.tasks.each { |t|
		selection << t if yield t
	    }
	}
	selection
    end
    public :select_tasks

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

    # Returns the value of the last expression executed in +rantfile+.
    # +rantfile+ has to be an Rant::Rantfile instance.
    def load_file(rantfile)
	msg 1, "source #{rantfile}"
	rv = nil
	begin
	    path = rantfile.path
	    rv = @context.instance_eval(File.read(path), path)
	rescue NameError => e
	    abort("Name error when loading `#{rantfile}':",
	    e.message, e.backtrace)
	rescue LoadError => e
	    abort("Load error when loading `#{rantfile}':",
	    e.message, e.backtrace)
	rescue ScriptError => e
	    abort("Script error when loading `#{rantfile}':",
	    e.message, e.backtrace)
	end
	unless @rantfiles.include?(rantfile)
	    @rantfiles << rantfile
	end
	rv
    end
    private :load_file

    # Get all rantfiles in dir.
    # If dir is nil, look in current directory.
    # Returns always an array with the pathes (not only the filenames)
    # to the rantfiles.
    def rantfiles_in_dir(dir=nil)
	files = []
	::Rant::RANTFILES.each { |rfn|
	    path = dir ? File.join(dir, rfn) : rfn
	    # We don't accept rantfiles with pathes that differ only
	    # in case. This protects from loading the same file twice
	    # on case insensitive file systems.
	    unless files.find { |f| f.downcase == path.downcase }
		files << path if test(?f, path)
	    end
	}
	files
    end

    def process_args
	# WARNING: we currently have to fool getoptlong,
	# by temporory changing ARGV!
	# This could cause problems (e.g. multithreading).
	old_argv = ARGV.dup
	ARGV.replace(@args.dup)
	cmd_opts = GetoptLong.new(*OPTIONS.collect { |lst| lst[0..-2] })
	cmd_opts.quiet = true
	cmd_opts.each { |opt, value|
	    case opt
	    when "--verbose": @opts[:verbose] += 1
	    when "--version"
		puts "rant #{Rant::VERSION}"
		raise Rant::RantDoneException
	    when "--help"
		show_help
		raise Rant::RantDoneException
	    when "--directory"
		# take care: we bypass the checks of self.rootdir=
		# because @run is true
		@opts[:directory] = value
	    when "--rantfile"
		@arg_rantfiles << value
	    when "--force-run"
		@force_targets << value
	    else
		# simple switch
		@opts[opt.sub(/^--/, '').tr('-', "_").to_sym] = true
	    end
	}
    rescue GetoptLong::Error => e
	abort(e.message)
    ensure
	rem_args = ARGV.dup
	ARGV.replace(old_argv)
	rem_args.each { |ra|
	    if ra =~ /(^[^=]+)=([^=]+)$/
		msg 2, "var: #$1=#$2"
		@var[$1] = $2
	    else
		@arg_targets << ra
	    end
	}
    end

    # Every task has to be registered with this method.
    def prepare_task(targ, block, clr = caller[2])
	#STDERR.puts "prepare task (#@current_subdir):\n  #{targ.inspect}"

	# Allow override of caller, useful for plugins and libraries
	# that define tasks.
	if targ.is_a? Hash
	    targ.reject! { |k, v| clr = v if k == :__caller__ }
	end
	ch = Hash === clr ? clr : Rant::Lib::parse_caller_elem(clr)

	name, pre = normalize_task_arg(targ, ch)

	file, is_new = rantfile_for_path(ch[:file])
	nt = yield(name, pre, block)
	nt.rantfile = file
        nt.project_subdir = file.project_subdir
	nt.line_number = ch[:ln]
	nt.description = @task_desc
	@task_desc = nil
	file.tasks << nt
	hash_task nt
	nt
    end
    public :prepare_task

    def hash_task(task)
	n = task.full_name
	#STDERR.puts "hash_task: `#{n}'"
	et = @tasks[n]
	case et
	when nil
	    @tasks[n] = task
	when Rant::Node
	    mt = [et, task]
	    @tasks[n] = mt
	else # assuming list of tasks
	    et << task
	end
    end

    # Tries to extract task name and prerequisites from the typical
    # argument to the +task+ command. +targ+ should be one of String,
    # Symbol or Hash. ch is the caller (hash with the elements :file
    # and :ln) and is used for error reporting and debugging.
    #
    # Returns two values, the first is a string which is the task name
    # and the second is an array with the prerequisites.
    def normalize_task_arg(targ, ch)
	name = nil
	pre = []
	
	# process and validate targ
	if targ.is_a? Hash
	    if targ.empty?
		abort_at(ch, "Empty hash as task argument, " +
		    "task name required.")
	    end
	    if targ.size > 1
		abort_at(ch, "Too many hash elements, " +
		    "should only be one.")
	    end
	    targ.each_pair { |k,v|
		name = normalize_task_name(k, ch)
		pre = v
	    }
	    unless ::Rant::FileList === pre
		if pre.respond_to? :to_ary
		    pre = pre.to_ary.dup
		    pre.map! { |elem|
			normalize_task_name(elem, ch)
		    }
		else
		    pre = [normalize_task_name(pre, ch)]
		end
	    end
	else
	    name = normalize_task_name(targ, ch)
	end

	[name, pre]
    end
    public :normalize_task_arg

    # Tries to make a task name out of arg and returns
    # the valid task name. If not possible, calls abort
    # with an appropriate error message using file and ln.
    def normalize_task_name(arg, ch)
	return arg if arg.is_a? String
	if Symbol === arg
	    arg.to_s
	elsif arg.respond_to? :to_str
	    arg.to_str
	else
	    abort_at(ch, "Task name has to be a string or symbol.")
	end
    end

    # Returns a Rant::Rantfile object as first value
    # and a boolean value as second. If the second is true,
    # the rantfile was created and added, otherwise the rantfile
    # already existed.
    def rantfile_for_path(path)
	# all rantfiles have an absolute path as path attribute
	abs_path = File.expand_path(path)
	if @rantfiles.any? { |rf| rf.path == abs_path }
	    file = @rantfiles.find { |rf| rf.path == abs_path }
	    [file, false]
	else
	    # create new Rantfile object
	    file = Rant::Rantfile.new abs_path
	    file.project_subdir = @current_subdir
	    @rantfiles << file
	    [file, true]
	end
    end

    # Returns the usual hash with :file and :ln as keys for the first
    # element in backtrace which comes from an Rantfile, or nil if no
    # Rantfile is involved.
    #
    # Note that this method is very time consuming!
    def get_ch_from_backtrace(backtrace)
	backtrace.each { |clr|
	    ch = ::Rant::Lib.parse_caller_elem(clr)
	    if ::Rant::Env.on_windows?
		return ch if @rantfiles.any? { |rf|
		    # sigh... a bit hackish: replace any backslash
		    # with a slash and remove any leading drive (e.g.
		    # C:) from the path
		    rf.path.tr("\\", "/").sub(/^\w\:/, '') ==
			ch[:file].tr("\\", "/").sub(/^\w\:/, '')
		}
	    else
		return ch if @rantfiles.any? { |rf|
		    rf.path == ch[:file]
		}
	    end
	}
	nil
    end

    def err_task_fail(e)
	msg = []
	t_msg = ["Task `#{e.tname}' fail."]
	orig = e
	loop { orig = orig.orig; break unless Rant::TaskFail === orig }
	unless orig == e
	    if Rant::RantError === orig
		ch = get_ch_from_backtrace(orig.backtrace)
		if ch
		    msg << pos_text(ch[:file], ch[:ln])
		    msg << orig.message
		else
		    msg << orig.message << orig.backtrace[0..4]
		end
	    elsif Rant::CommandError === orig
		msg << orig.message if @opts[:err_commands]
	    elsif orig && !(Rant::RantAbortException === orig)
		msg << orig.message << orig.backtrace[0..4]
	    end
	end
	err_msg msg unless msg.empty?
	err_msg t_msg
    end

    # Just ensure that Rant.rac holds an RantApp after loading
    # this file. The code in initialize will register the new app with
    # Rant.rac= if necessary.
    self.new

end	# class Rant::RantApp
