
require 'fileutils'
require 'rant/rantenv'

module Rant

    class FileList < Array

	attr_reader :pattern

	class << self
	    def [] pattern
		new(pattern).no_suffix("~").no_suffix(".bak")
	    end
	end

	def initialize(pattern, flags = 0)
	    super(Dir.glob(pattern, flags))
	    @actions = []
	end

	def +(other)
	    fl = self.dup
	    fl.concat(other.to_ary)
	    fl
	end

	# Reevaluate pattern. Replay all modifications
	# if replay is given.
	def update(replay = true)
	    self.replace(Dir[pattern])
	    if replay
		@actions.each { |action|
		    self.send(*action)
		}
	    end
	    @actions.clear
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
	    @actions << [:no_dir, name]
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
	    self
	end

	# Remove all files which have the given name.
	def no_file(name)
	    @actions << [:no_file, name]
	    self.reject! { |entry|
		entry == name and test(?f, entry)
	    }
	    self
	end

	# Remove all entries which contain an element
	# with the given suffix.
	def no_suffix(suffix)
	    @actions << [:no_suffix, suffix]
	    elems = elem = nil
	    self.reject! { |entry|
		elems = Sys.split_path(entry)
		elems.any? { |elem|
		    elem =~ /#{suffix}$/
		}
	    }
	    self
	end

	# Remove all entries which contain an element
	# with the given prefix.
	def no_prefix(prefix)
	    @actions << [:no_prefix, prefix]
	    elems = elem = nil
	    self.reject! { |entry|
		elems = Sys.split_path(entry)
		elems.any? { |elem|
		    elem =~ /^#{prefix}/
		}
	    }
	    self
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

	# If supported, make a symbolic link, otherwise
	# fall back to copying.
	def safe_ln(*args)
	    unless self.class.symlink_supported
		cp(*args)
	    else
		begin
		    ln(*args)
		rescue Errno::EOPNOTSUPP
		    self.class.symlink_supported = false
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
