
# archive.rb - Archiving support for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>
#
# This file currently doesn't contain a generator. Thus an <tt>import
# "archive"</tt> doesn't make sense. Do an <tt>import
# "archive/tgz"</tt> or <tt>import "archive/zip"</tt> instead.

require 'rant/rantlib'
require 'rant/import/subfile'
#require 'rant/tempfile' #rant-import:uncomment

module Rant::Generators::Archive
    # A subclass has to provide a +define_task+ method to act as a
    # generator.
    class Base
	extend Rant::MetaUtils

	def self.rant_gen(rac, ch, args, &block)
	    pkg_name = args.shift
	    unless pkg_name
		rac.abort_at(ch,
		    "#{self} takes at least one argument (package name)")
	    end
	    opts = nil
	    flags = []
	    arg = args.shift
	    case arg
	    when String
		basedir = pkg_name
		pkg_name = arg
	    when Symbol
		flags << arg
	    else
		opts = arg
	    end
	    flags << arg while Symbol === (arg = args.shift)
	    opts ||= (arg || {})
	    unless args.empty?
		rac.abort_at(ch, "#{self}: too many arguments")
	    end

	    pkg = self.new(pkg_name)
	    pkg.basedir = basedir if basedir
	    pkg.rac = rac
	    pkg.ch = ch
	    flags.each { |f|
		case f
		when :manifest
		    pkg.manifest = "MANIFEST"
		when :verbose
		    # TODO
		when :quiet
		    # TODO
		else
		    rac.warn_msg(
			"#{self}: ignoring unknown flag #{flag}")
		end
	    }
	    if opts.respond_to? :to_hash
		opts = opts.to_hash
	    else
		rac.abort_at(ch,
		    "#{self}: option argument has to be a hash.")
	    end
	    opts.each { |k, v|
		case k
		when :version
		    pkg.version = v
		when :extension
		    pkg.extension = v
		when :files
		    pkg.files = v
		when :manifest
		    pkg.manifest = v
		when :files_only
		    pkg.files_only = v
		else
		    rac.warn_msg(
			"#{self}: ignoring unknown option #{k}")
		end
	    }
            desc = pkg.rac.pop_desc
	    pkg.define_manifest_task if opts[:files] && opts[:manifest]
            pkg.rac.cx.desc desc
	    pkg.define_task
	    pkg
	end

	string_attr :name
	string_attr :version
	string_attr :basedir
	string_attr :extension
	rant_attr :files
	string_attr :manifest
	attr_reader :archive_path
	# If this is true, directories won't be included for packaging
	# (only files). Defaults to true.
	rant_attr :files_only
	# Caller information, e.g.: {:file => "Rantfile", :ln => 10}
	attr_accessor :ch

	def initialize(name, files = nil)
	    self.name = name or raise "package name required"
	    @files = files
	    @version, @extension, @archive_path = nil
	    @rac = nil
	    @pkg_task = nil
	    @ch = nil
	    @files_only = false
	    @manifest_task = nil
	    @basedir = nil
            @res_files = nil
            @manifest = nil
            @dist_dir_task = nil
	end

	def rac
	    @rac
	end
	def rac=(val)
	    @rac = val
	    @pkg_task = nil
	end

	# Path to archive file.
	def path
	    if basedir
		File.join(basedir, get_archive_path)
	    else
		get_archive_path
	    end
	end
        alias to_rant_target path

	# Path to archive without basedir.
	def get_archive_path
	    return @archive_path if @archive_path
	    path = name.dup
	    path << "-#@version" if @version
	    path << @extension if @extension
	    @archive_path = path
	end

	# This method sets @res_files to the return value, a list of
	# files to include in the archive.
	def get_files
            return @res_files if @res_files
	    fl = @files ? @files.dup : []
	    if @manifest
                fl = read_manifest unless @files
                fl = Rant::RacFileList.filelist(@rac, fl)
                fl << @manifest
	    elsif @files_only
                fl = Rant::RacFileList.filelist(@rac, fl)
		fl.no_dirs
            else
                fl = Rant::RacFileList.filelist(@rac, fl)
	    end
            # remove leading `./' relicts
            @res_files = fl.lazy_map! { |fn| fn.sub(/^\.\/(?=.)/,'') }
            if defined?(@dist_path) && @dist_path
                # Remove entries from the dist_path directory, which
                # would create some sort of weird recursion.
                #
                # Normally, the Rantfile writer should care himself,
                # but since I tapped into this trap frequently now...
                @res_files.exclude(/^#{Regexp.escape @dist_path}/)
            end
            @res_files.lazy_uniq!.lazy_sort!
	end

	# Creates an (eventually) temporary manifest file and yields
	# with the path of this file as argument.
	def with_manifest
	    fl = get_files
	    if @manifest
		rac.build @manifest
		yield @manifest
	    else
                require 'rant/tempfile' #rant-import:remove
		tf = Rant::Tempfile.new "rant"
		begin
		    fl.each { |path| tf.puts path }
		    tf.close
		    yield(tf.path)
		ensure
		    tf.unlink
		end
	    end
	    nil
	end

	def define_manifest_task
	    return @manifest_task if @manifest_task
	    @manifest_task =
                ::Rant::Generators::Task.rant_gen(
                        @rac, @ch, [@manifest]) do |t|
		    def t.each_target
			goto_task_home
			yield name
		    end
		    t.needed {
                        # fl refers to @res_files
                        fl = get_files
			if test ?f, @manifest
                            read_manifest != @res_files.to_ary
			else
			    true
			end
		    }
		    t.act {
                        write_manifest get_files
		    }
		end
	end

	private
	def read_manifest
	    fl = []
	    open @manifest do |f|
		f.each { |line|
		    line.chomp!
		    fl << line unless line.strip.empty?
		}
	    end
	    fl
	end
	def write_manifest fl
	    @rac.cmd_msg "writing #@manifest" if @rac
	    open @manifest, "w" do |f|
		fl.each { |path| f.puts path }
	    end
	end
	def define_cmd_task
	    return @pkg_task if @pkg_task
	    targ = {get_archive_path => get_files}
	    @pkg_task =
		::Rant::Generators::SubFile.rant_gen(
			@rac, @ch, [basedir, targ].compact) do |t|
		    with_manifest { |path| yield(path, t) }
		end
	end
	# Define a task to package one dir. For usage in subclasses.
	# This method sets the following instance variables:
	# [@dist_dirname]  The name of the directory which shall be
	#                  the root of all entries in the archive.
	# [@dist_root]	   The directory in which the @dist_dirname
	#                  directory will be created with contents for
	#                  archiving.
	# [@dist_path]     @dist_root/@dist_dirname (or just
	#                  @dist_dirname if @dist_root is ".")
	#
	# The block supplied to this method will be the action
	# to create the archive file (e.g. by invoking the tar
	# command).
	def define_task_for_dir(&block)
	    return @pkg_task if @pkg_task

	    @dist_dirname = File.split(name).last
	    @dist_dirname << "-#@version" if @version
	    @dist_root, = File.split path
	    @dist_path = (@dist_root == "." ?
		@dist_dirname : File.join(@dist_root, @dist_dirname))
            get_files # set @res_files

            targ = {get_archive_path => [@dist_path]}
	    #STDERR.puts "basedir: #{basedir}, fn: #@archive_path"
            @pkg_task = ::Rant::Generators::SubFile.rant_gen(
            	@rac, @ch, [basedir, targ].compact, &block)

	    define_dist_dir_task

	    @pkg_task
	end

	# This method sets the instance variable @dist_dir_task.
	# Assumes that @res_files is set.
	#
	# Returns a task which creates the directory @dist_path and
	# links/copies @res_files to @dist_path.
	def define_dist_dir_task
	    return if @dist_dir_task
	    cx = @rac.cx
	    if @basedir
		@basedir.sub!(/\/$/, '') if @basedir.length > 1
		c_dir = @dist_path.sub(/^#@basedir\//, '')
		targ = {c_dir => @res_files}
	    else
		targ = {@dist_path => @res_files}
	    end
	    @dist_dir_task = Rant::Generators::Directory.rant_gen(
		    @rac, @ch, [@basedir, targ].compact) { |t|
		# ensure to create new and empty destination directory
		if Dir.entries(@dist_path).size > 2	# "." and ".."
		    cx.sys.rm_rf(@dist_path)
		    cx.sys.mkdir(@dist_path)
		end
		# evaluate directory structure first
		dirs = []
		fl = []
		@res_files.each { |e|
		    if test(?d, e)
			dirs << e unless dirs.include? e
		    else	# assuming e is a file
			fl << e
			dir = File.dirname(e)
			dirs << dir unless dir == "." || dirs.include?(dir)
		    end
		}
		# create directory structure
		dirs.each { |dir|
		    dest = File.join(@dist_path, dir)
		    cx.sys.mkpath(dest) unless test(?d, dest)
		}
		# link or copy files
		fl.each { |f|
		    dest = File.join(@dist_path, f)
		    cx.sys.safe_ln(f, dest)
		}
	    }
	end
    end # class Base
end # module Rant::Generators::Archive
