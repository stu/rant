
require 'fileutils'
require 'rant/env'

module Rant
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

    module FileUtils
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

	# Override this method to control messages.
	# This methods prints each argument on its
	# own line to $stderr.
	def rant_fu_msg *args
	    $stderr.puts args
	end

	def fu_output_message(msg)	#:nodoc:
	    rant_fu_msg(msg)
	end

	def sh(*cmd_args, &block)
	    cmd = cmd_args.join(" ")
	    unless block_given?
		block = lambda { |succ, status|
		    succ or raise CommandError.new(cmd, status)
		}
	    end
	    rant_fu_msg cmd
	    block.call(system(*cmd_args), $?)
	end

	def ruby(*args, &block)
	    if args.size > 1
		sh(*([Env::RUBY] + args), &block)
	    else
		sh(Env::RUBY + ' ' + args.join(' '), &block)
	    end
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

	module_function :rant_fu_msg, :sh, :ruby, :safe_ln, :split_path
    end	# module FileUtils
end	# module Rant
