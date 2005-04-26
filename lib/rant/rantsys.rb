
require 'fileutils'
require 'rant/rantenv'

module Rant

    class FileList
	include Enumerable

	ESC_SEPARATOR = Regexp.escape(File::SEPARATOR)
	ESC_ALT_SEPARATOR = File::ALT_SEPARATOR ?
	    Regexp.escape(File::ALT_SEPARATOR) : nil

	# Flags for the File::fnmatch method.
	# Initialized to 0.
	attr_accessor :glob_flags
	
	attr_reader :ignore_rx

	class << self
	    def [](*patterns)
		new(*patterns)
	    end
	end

	def initialize(*patterns)
	    @glob_flags = 0
	    @files = []
	    @actions = patterns.map { |pat| [:apply_include, pat] }
	    @ignore_rx = nil
	    @pending = true
	    yield self if block_given?
	end

	def dup
	    c = super
	    c.files = @files.dup
	    c.actions = @actions.dup
	    c.ignore_rx = @ignore_rx.dup if @ignore_rx
	    c
	end

	protected
	attr_accessor :actions, :files
	attr_accessor :pending

	public
	### Methods having an equivalent in the Array class. #########

	def each &block
	    resolve if @pending
	    @files.each(&block)
	end

	def to_ary
	    resolve if @pending
	    @files
	end

	def to_a
	    to_ary
	end

	def +(other)
	    case other
	    when Array
		dup.files.concat(other)
	    when FileList
		c = other.dup
		c.actions.concat(@actions)
		c.files.concat(@files)
		c.pending = !c.actions.empty?
		c
	    else
		raise "argument has to be an Array or FileList"
	    end
	end

	def <<(file)
	    @files << file unless file =~ ignore_rx
	    self
	end

	def concat(ary)
	    resolve if @pending
	    ix = ignore_rx
	    @files.concat(ary.to_ary.reject { |f| f =~ ix })
	    self
	end

	def size
	    resolve if @pending
	    @files.size
	end

	def method_missing(sym, *args, &block)
	    if @files.respond_to? sym
		resolve if @pending
		fh = @files.hash
		rv = @files.send(sym, *args, &block)
		@pending = true unless @files.hash == fh
		rv.equal?(@files) ? self : rv
	    else
		super
	    end
	end
	##############################################################

	def resolve
	    @pending = false
	    @actions.each { |action|
		self.send(*action)
	    }
	    @actions.clear
	    ix = ignore_rx
	    if ix
		@files.reject! { |f| f =~ ix }
	    end
	end

	def include(*patterns)
	    patterns.flatten.each { |pat|
		@actions << [:apply_include, pat]
	    }
	    @pending = true
	    self
	end
	alias glob include

	def apply_include(pattern)
	    @files.concat Dir.glob(pattern, @glob_flags)
	end
	private :apply_include

	def exclude(*patterns)
	    patterns.each { |pat|
		if Regexp === pat
		    @actions << [:apply_exclude_rx, pat]
		else
		    @actions << [:apply_exclude, pat]
		end
	    }
	    @pending = true
	    self
	end

	def ignore(*patterns)
	    patterns.each { |pat|
		add_ignore_rx(Regexp === pat ? pat : mk_all_rx(pat))
	    }
	    @pending = true
	    self
	end

	def add_ignore_rx(rx)
	    @ignore_rx =
	    if @ignore_rx
		Regexp.union(@ignore_rx, rx)
	    else
		rx
	    end
	end
	private :add_ignore_rx

	def apply_exclude(pattern)
	    @files.reject! { |elem|
		File.fnmatch? pattern, elem, @glob_flags
	    }
	end
	private :apply_exclude

	def apply_exclude_rx(rx)
	    @files.reject! { |elem|
		elem =~ rx
	    }
	end
	private :apply_exclude_rx

	def exclude_all(*files)
	    files.each { |file|
		@actions << [:apply_exclude_rx, mk_all_rx(file)]
	    }
	    @pending = true
	    self
	end
	alias shun exclude_all

	if File::ALT_SEPARATOR
	    # TODO: check for FS case sensitivity?
	    def mk_all_rx(file)

		/(^|(#{ESC_SEPARATOR}|#{ESC_ALT_SEPARATOR})+)
		    #{Regexp.escape(file)}
		    ((#{ESC_SEPARATOR}|#{ESC_ALT_SEPARATOR})+|$)/x
	    end
	else
	    def mk_all_rx(file)
		/(^|#{ESC_SEPARATOR}+)
		    #{Regexp.escape(file)}
		    (#{ESC_SEPARATOR}+|$)/x
	    end
	end
	private :mk_all_rx

	# Remove all entries which contain a directory with the
	# given name.
	# If no argument or +nil+ given, remove all directories.
	#
	# Example:
	#	file_list.no_dir "CVS"
	# would remove the following entries from file_list:
	#	CVS/
	#       src/CVS/lib.c
	#       CVS/foo/bar/
	def no_dir(name = nil)
	    @actions << [:apply_no_dir, name]
	    @pending = true
	    self
	end

	def apply_no_dir(name)
	    entry = nil
	    unless name
		@files.reject! { |entry|
		    test(?d, entry)
		}
		return
	    end
	    elems = nil
	    @files.reject! { |entry|
		elems = Sys.split_path(entry)
		i = elems.index(name)
		if i
		    path = File.join(*elems[0..i])
		    test(?d, path)
		else
		    false
		end
	    }
	end
	private :apply_no_dir

	# Remove all files which have the given name.
	def no_file(name)
	    @actions << [:apply_no_file, name]
	    @pending = true
	    self
	end

	def apply_no_file(name)
	    @files.reject! { |entry|
		entry == name and test(?f, entry)
	    }
	end
	private :apply_no_file

	# Remove all entries which contain an element
	# with the given suffix.
	def no_suffix(suffix)
	    @actions << [:no_suffix, suffix]
	    @pending = true
	    self
	end

	def apply_no_suffix(suffix)
	    elems =  nil
	    elem = nil
	    @files.reject! { |entry|
		elems = Sys.split_path(entry)
		elems.any? { |elem|
		    elem =~ /#{suffix}$/
		}
	    }
	end
	private :apply_no_suffix

	# Remove all entries which contain an element
	# with the given prefix.
	def no_prefix(prefix)
	    @actions << [:no_prefix, prefix]
	    @pending = true
	    self
	end

	def apply_no_prefix(prefix)
	    elems = elem = nil
	    @files.reject! { |entry|
		elems = Sys.split_path(entry)
		elems.any? { |elem|
		    elem =~ /^#{prefix}/
		}
	    }
	end
	private :apply_no_prefix

	# Get a string with all entries. This is very usefull
	# if you invoke a shell:
	#	files # => ["foo/bar", "with space"]
	#	sh "rdoc #{files.arglist}"
	# will result on windows:
	#	rdoc foo\bar "with space"
	# on other systems:
	#	rdoc foo/bar 'with space'
	def arglist
	    to_ary.arglist
	end
    end	# class FileList

    class RacFileList < FileList

	attr_reader :subdir

	def initialize(rac, *patterns)
	    @rac = rac
	    @subdir = @rac.current_subdir
	    super(*patterns)
	    @ignore_hash = nil
	    update_ignore_rx
	end

	private :ignore

	def ignore_rx
	    update_ignore_rx
	    @ignore_rx
	end

	alias filelist_resolve resolve
	def resolve
	    @rac.in_project_dir(@subdir) { filelist_resolve }
	end

	def each &block
	    resolve if @pending
	    @rac.in_project_dir(@subdir) {
		filelist_resolve
		@files.each(&block)
	    }
	end

	private
	def update_ignore_rx
	    ri = @rac.var[:ignore]
	    rh = ri.hash
	    unless rh == @ignore_hash
		@ignore_rx = nil
		ignore(*ri) if ri
		@ignore_hash = rh
	    end
	end
    end	# class RacFileList

    class MultiFileList

	attr_reader :cur_list
	
	def initialize(rac)
	    @rac = rac
	    @cur_list = RacFileList.new(@rac)
	    @lists = [@cur_list]
	end

	def each_entry &block
	    @lists.each { |list|
		list.each &block
	    }
	end

	def add(filelist)
	    # TODO: validate filelist
	    @cur_list = filelist
	    @lists << filelist
	    self
	end

	def method_missing(sym, *args, &block)
	    if @cur_list && @cur_list.respond_to?(sym)
		if @cur_list.subdir == @rac.current_subdir
		    @cur_list.send(sym, *args, &block)
		else
		    add(RacFileList.new(@rac))
		    @cur_list.send(sym, *args, &block)
		end
	    else
		super
	    end
	end
    end	# class MultiFileList

    class CommandError < StandardError
	attr_reader :cmd
	attr_reader :status
	def initialize(cmd, status=nil, msg=nil)
	    @msg = msg
	    @cmd = cmd
	    @status = status
	end
	def message
	    if !@msg && cmd
		if status
		    "Command failed with status #{status.to_s}:\n" +
		    "[#{cmd}]"
		else
		    "Command failed:\n[#{cmd}]"
		end
	    else
		@msg
	    end
	end
    end

    module Sys
	include ::FileUtils::Verbose
	# We include the verbose version of FileUtils
	# and override the fu_output_message to control
	# messages.

	# Set symlink support flag to true and try the first
	# time (in safe_ln) if symlinks are supported and if
	# not, reset this flag.
	@symlink_supported = true
	class << self
	    attr_accessor :symlink_supported
	end

	# We override the output method of the FileUtils module to
	# allow the Rant application to control output.
	def fu_output_message(msg)	#:nodoc:
	    ::Rant.rac.cmd_msg msg if ::Rant.rac
	end

	def sh(*cmd_args, &block)
	    cmd_args.flatten!
	    cmd = cmd_args.join(" ")
	    fu_output_message cmd
	    if block_given?
		block[system(*cmd_args), $?]
	    else
		system(*cmd_args) or raise CommandError.new(cmd, $?)
	    end
	end

	def ruby(*args, &block)
	    if args.size > 1
		sh([Env::RUBY] + args, &block)
	    else
		sh("#{Env::RUBY} #{args.first}", &block)
	    end
	end

	# Returns a string that can be used as a valid path argument on the
	# shell respecting portability issues.
	def sp path
	    Env.shell_path path
	end

	# If supported, make a hardlink, otherwise
	# fall back to copying.
	def safe_ln(*args)
	    unless Sys.symlink_supported
		cp(*args)
	    else
		begin
		    ln(*args)
		rescue Errno::EOPNOTSUPP
		    Sys.symlink_supported = false
		    cp(*args)
		end
	    end
	end

	# Split a path in all elements.
	def split_path(path)
	    base, last = File.split(path)
	    return [last] if base == "." || last == "/"
	    return [base, last] if base == "/"
	    split_path(base) + [last]
	end

	extend self

    end	# module Sys

    class SysObject
	include Sys

	# The controlling Rant compiler.
	attr_reader :rac

	def initialize(rac)
	    @rac = rac or
		raise ArgumentError, "controller required"
	end

	def glob(*args, &block)
	    fl = RacFileList.new(@rac, *args)
	    fl.instance_eval(&block) if block
	    fl
	end

	def [](*patterns)
	    RacFileList.new(@rac, *patterns)
	end

	private
	def fu_output_message(cmd)
	    @rac.cmd_msg cmd
	end
    end
end	# module Rant
