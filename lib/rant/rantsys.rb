
require 'fileutils'
require 'rant/rantenv'

module Rant

    class Glob < String
	class << self
	    # A synonym for +new+.
	    def [](pattern)
		new(pattern)
	    end
	end
    end

    class FileList < Array

	# Flags for the File::fnmatch method.
	# Initialized to 0.
	attr_accessor :flags

	class << self
	    def [](*patterns)
		new(*patterns)
	    end
	end

	# IMPORTANT NOTE: Array#dup and Array#clone seem to do some
	# very special things which results in things like this:
	# (with a FileList implementation that doesn't override #dup
	# and #clone, the inspect method wasn't overrided to allow
	# this test, pwd contained 15 entries, Ruby 1.8.2)
=begin
	irb(main):009:0> fl = FileList["*"]
	=> []
	irb(main):010:0> cl = fl.clone
	=> []
	irb(main):011:0> cl.size
	=> 15
	irb(main):012:0> fl.size
	=> 0
	irb(main):013:0> fl.to_a
	=> []
=end
    
	# The above should be related to this problem. The following
	# Rantfile will actually never remove anything:
=begin
	task :clean do
	    sys.rm_f FileList["*.{exe,dll,obj}"]
	end
=end
	# (Same problem with corresponding Rakefile.)
	# The rm_f command first does a [arg].flatten.map, where arg
	# is our FileList.
	#
	# Think I finally found the problem: The flatten method seems
	# to copy elements directly before calling any method on our
	# FileList because our FileList is an Array.
	#
	# After testing and searching in the Ruby sources, I found out
	# that it can be solved by overriding the is_a? method.
	
	# override Array methods
	ml = Array.instance_methods - Object.instance_methods
	%w(to_a inspect dup clone is_a?).each {
	    |m| ml << m unless ml.include? m
	}
	ml.each { |m|
	    #puts "override #{m}"
	    eval <<-EOM
		def #{m}(*args)
		    resolve if @pending
		    super
		end
	    EOM
	}

	def initialize(*patterns)
	    super()
	    @flags = 0
	    @actions = patterns.map { |pat| [:apply_include, pat] }
	    @pending = true
	end

	#def +(other)
	#    self.dup.concat(other.to_ary)
	#end

	def resolve
	    @pending = false
	    @actions.each { |action|
		self.send(*action)
	    }
	    @actions.clear
	end

	def include(*patterns)
	    patterns.each { |pat|
		@actions << [:apply_include, pat]
	    }
	    @pending = true
	    self
	end

	def apply_include(pattern)
	    self.concat Dir.glob(pattern, @flags)
	end

	def exclude(*patterns)
	    patterns.each { |pat|
		@actions << [:apply_exclude, pat]
	    }
	    @pending = true
	    self
	end

	def apply_exclude(pattern)
	    self.reject! { |elem|
		File.fnmatch? pattern, elem, @flags
	    }
	end

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
		self.reject! { |entry|
		    test(?d, entry)
		}
		return self
	    end
	    elems = nil
	    self.reject! { |entry|
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

	# Remove all files which have the given name.
	def no_file(name)
	    @actions << [:apply_no_file, name]
	    @pending = true
	    self
	end

	def apply_no_file(name)
	    self.reject! { |entry|
		entry == name and test(?f, entry)
	    }
	end

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
	    self.reject! { |entry|
		elems = Sys.split_path(entry)
		elems.any? { |elem|
		    elem =~ /#{suffix}$/
		}
	    }
	end

	# Remove all entries which contain an element
	# with the given prefix.
	def no_prefix(prefix)
	    @actions << [:no_prefix, prefix]
	    @pending = true
	    self
	end

	def apply_no_prefix(prefix)
	    elems = elem = nil
	    self.reject! { |entry|
		elems = Sys.split_path(entry)
		elems.any? { |elem|
		    elem =~ /^#{prefix}/
		}
	    }
	end

	# Get a string with all entries. This is very usefull
	# if you invoke a shell:
	#	files # => ["foo/bar", "with space"]
	#	sh "rdoc #{files.arglist}"
	# will result on windows:
	#	rdoc foo\bar "with space"
	# on other systems:
	#	rdoc foo/bar 'with space'
=begin
	def arglist
	    self.list.join(' ')
	end

	def list
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
=end
    end	# class FileList

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
	    ::Rant.rantapp.cmd_msg msg
	end

	def sh(*cmd_args, &block)
	    cmd_args.flatten!
	    cmd = cmd_args.join(" ")
	    unless block_given?
		block = lambda { |succ, status|
		    succ or raise CommandError.new(cmd, status)
		}
	    end
	    fu_output_message cmd
	    block.call(system(*cmd_args), $?)
	end

	def ruby(*args, &block)
	    if args.size > 1
		sh(*([Env::RUBY] + args), &block)
	    else
		sh(Env::RUBY + ' ' + args.join(' '), &block)
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

	# This could be an Rant application. It has to respond to
	# +:cmd_msg+.
	attr_reader :controller

	def initialize(controller)
	    @controller = controller or
		raise ArgumentError, "controller required"
	end

	private
	def fu_output_message(cmd)
	    @controller.cmd_msg cmd
	end
    end
end	# module Rant
