
# rantsys.rb - Support for the +sys+ method/object.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'fileutils'
require 'rant/import/filelist/core'

# Fix FileUtils::Verbose visibility issue
if RUBY_VERSION == "1.8.3"
    module FileUtils
        METHODS = singleton_methods - %w(private_module_function
            commands options have_option? options_of collect_method)
        module Verbose
            class << self
                public(*::FileUtils::METHODS)
            end
            public(*::FileUtils::METHODS)
        end
    end
end

if RUBY_VERSION < "1.8.1"
    module FileUtils
        undef_method :fu_list
        def fu_list(arg)
            arg.respond_to?(:to_ary) ? arg.to_ary : [arg]
        end
    end
end

module Rant
    class RacFileList < FileList

	attr_reader :subdir
	attr_reader :basedir

	def initialize(rac, store = [])
	    super(store)
	    @rac = rac
	    @subdir = @rac.current_subdir
	    @basedir = Dir.pwd
	    @ignore_hash = nil
            @add_ignore_args = []
	    update_ignore_rx
	end
        def dup
            c = super
            c.instance_variable_set(
                :@add_ignore_args, @add_ignore_args.dup)
            c
        end
        def copy
            c = super
            c.instance_variable_set(
                :@add_ignore_args, @add_ignore_args.map { |e| e.dup })
            c
        end
        alias filelist_ignore ignore
        def ignore(*patterns)
            @add_ignore_args.concat patterns
            self
        end
	def ignore_rx
	    update_ignore_rx
	    @ignore_rx
	end
	alias filelist_resolve resolve
	def resolve
	    Sys.cd(@basedir) { filelist_resolve }
	end
	def each_cd(&block)
	    old_pwd = Dir.pwd
	    Sys.cd(@basedir)
	    filelist_resolve if @pending
	    @items.each(&block)
	ensure
	    Sys.cd(old_pwd)
	end
	private
	def update_ignore_rx
	    ri = @rac.var[:ignore]
            ri = ri ? (ri + @add_ignore_args) : @add_ignore_args
	    rh = ri.hash
	    unless rh == @ignore_hash
		@ignore_rx = nil
		filelist_ignore(*ri)
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

	def each_entry(&block)
	    @lists.each { |list|
		list.each_cd(&block)
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
		    "Command failed with status #{status.exitstatus}:\n" +
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
            # direct calls through Rant::Sys are silent
	end
        private :fu_output_message

        def fu_each_src_dest(src, *rest)
            src = src.to_ary if src.respond_to? :to_ary
            super(src, *rest)
        end
        private :fu_each_src_dest

	# Run an external command. When given one argument, this is
	# subject to shell interpretation. Otherwise the first
	# argument is the program to run, following arguments are
	# given as arguments to the program.
	#
	# Note: This method is called on +sys <some_string>+
	# invocation in an Rantfile.
	def sh(*cmd_args, &block)
	    cmd_args.flatten!
	    cmd = cmd_args.join(" ")
	    fu_output_message cmd
            success = system(*cmd_args)
	    if block_given?
                block[$?]
            elsif !success
		raise CommandError.new(cmd, $?)
	    end
	end

        def uptodate?(new, old, *rest)
          # FileUtils in 1.8 allowed old to be a string,
          # in 1.9 it must be an array. We override it here
          # to preserve backwards-compatibility.
          if old.respond_to?(:to_ary)
            old = old.to_ary
          else
            old = [old]
          end
          super(new, old, *rest)
        end

	# Run a new Ruby interpreter with the given arguments:
	#     sys.ruby "install.rb"
	def ruby(*args, &block)
            if args.empty?
                # The empty string argument ensures that +system+
                # doesn't start a subshell but invokes ruby directly.
                # The empty string argument is ignored by ruby.
                sh(Env::RUBY_EXE, '', &block)
            else
                sh(args.unshift(Env::RUBY_EXE), &block)
            end
	end
        # Returns the value of +block+ if a block is given, a true
        # value otherwise.
        def cd(dir, &block)
            fu_output_message "cd #{dir}"
            orig_pwd = Dir.pwd
            Dir.chdir dir
            if block
                begin
                    block.arity == 0 ? block.call : block.call(Dir.pwd)
                ensure
                    fu_output_message "cd -"
                    Dir.chdir orig_pwd
                end
            else
                self
            end
        end

	# If supported, make a hardlink, otherwise
	# fall back to copying.
	def safe_ln(src, dest)
            dest = dest.to_str
            src = src.respond_to?(:to_ary) ? src.to_ary : src.to_str
	    unless Sys.symlink_supported
		cp(src, dest)
	    else
		begin
		    ln(src, dest)
		rescue Exception # SystemCallError # Errno::EOPNOTSUPP
		    Sys.symlink_supported = false
		    cp(src, dest)
		end
	    end
	end

        def ln_f(src, dest)
            ln(src, dest, :force => true)
        end

        def split_path(str)
            str.split(Env.on_windows? ? ";" : ":")
        end

        if Env.on_windows?
            def root_dir?(path)
                path == "/" || path == "\\" ||
                    path =~ %r{\A[a-zA-Z]+:(\\|/)\Z}
                # how many drive letters are really allowed on
                # windows?
            end
            def absolute_path?(path)
                path =~ %r{\A([a-zA-Z]+:)?(/|\\)}
            end
        else
            def root_dir?(path)
                path == "/"
            end
            def absolute_path?(path)
                path =~ %r{\A/}
            end
        end

        extend self

        if RUBY_VERSION >= "1.8.4"  # needed by 1.9.0, too
            class << self
                public(*::FileUtils::METHODS)
            end
            public(*::FileUtils::METHODS)
        end

    end	# module Sys

    # An instance of this class is returned from the +sys+ method in
    # Rantfiles (when called without arguments).
    #     sys.rm_rf "tmp"
    # In this (Rantfile) example, the +rm_rf+ message is sent to an
    # instance of this class.
    class SysObject
	include Sys
	def initialize(rant)
	    @rant = rant or
		raise ArgumentError, "rant application required"
	end
        # Preferred over directly modifying var[:ignore]. var[:ignore]
        # might go in future.
        def ignore(*patterns)
            @rant.var[:ignore].concat(patterns)
            nil
        end
        # <code>sys.filelist(arg)</code>::
        #       corresponds to <code>Rant::FileList(arg)</code>
        # <code>sys.filelist</code>::
        #       corresponds to <code>Rant::FileList.new</code>
        def filelist(arg = Rant.__rant_no_value__)
            if Rant.__rant_no_value__.equal?(arg)
                RacFileList.new(@rant)
            elsif arg.respond_to?(:to_rant_filelist)
                arg.to_rant_filelist
            elsif arg.respond_to?(:to_ary)
                RacFileList.new(@rant, arg.to_ary)
            else
                raise TypeError,
                    "cannot convert #{arg.class} into Rant::FileList"
            end
        end
        # corresponds to <code>Rant::FileList[*patterns]</code>.
	def [](*patterns)
	    RacFileList.new(@rant).hide_dotfiles.include(*patterns)
	end
        # corresponds to <code>Rant::FileList.glob(*patterns,
        # &block)</code>.
	def glob(*patterns, &block)
	    fl = RacFileList.new(@rant).hide_dotfiles.include(*patterns)
            fl.ignore(".", "..")
            if block_given? then yield fl else fl end
	end
        # corresponds to <code>Rant::FileList.glob_all(*patterns,
        # &block)</code>.
        def glob_all(*patterns, &block)
	    fl = RacFileList.new(@rant).include(*patterns)
            fl.ignore(".", "..") # use case: "*.*" as pattern
            if block_given? then yield fl else fl end
        end
        def expand_path(path)
            File.expand_path(@rant.project_to_fs_path(path))
        end
	private
	# Delegates FileUtils messages to +rant+.
	def fu_output_message(cmd)
	    @rant.cmd_msg cmd
	end
    end
end # module Rant
# this line prevents ruby 1.8.3 from crashing with: [BUG] unknown node type 0
