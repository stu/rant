
# package.rb - Rant packaging support.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'
require 'rant/import/subfile'

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
	    pkg.define_manifest_task if opts[:files] && opts[:manifest]
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
	attr_accessor :rac
	

	def initialize(name, files = nil)
	    self.name = name or raise "package name required"
	    @files = files
	    @version, @extension, @archive_path = nil
	    @rac = nil
	    @pkg_task = nil
	    @ch = nil
	    @files_only = true
	    @manifest_task = nil
	    @data = {}
	    @basedir = nil
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
	    fl = @files ? @files.dup : []
	    if @manifest
		if fl.empty?
		    fl = read_manifest
		else
		    fl << @manifest
		end
	    elsif @files_only
		fl = fl.reject { |f| test ?d, f }
	    end
	    @res_files = fl
	end

	# Creates an (eventually) temporary manifest file and yields
	# with the path of this file as argument.
	def with_manifest
	    fl = get_files
	    if @manifest
		rac.make @manifest
		yield @manifest
	    else
		require 'tempfile'
		tf = Tempfile.new "rant"
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
		@rac.gen ::Rant::Task, @manifest do |t|
		    def t.each_target
			goto_task_home
			yield name
		    end
		    t.needed {
			@data["fl_ary"] = (@files + [@manifest]).sort.uniq
			if @files_only
			    @data["fl_ary"].reject! { |f| test ?d, f }
			end
			if test ?f, @manifest
			    read_manifest != @data["fl_ary"]
			else
			    true
			end
		    }
		    t.act {
			write_manifest @data["fl_ary"]
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
	    #targ[:__caller__] = @ch if @ch
	    #args = [::Rant::Generators::SubFile, basedir, targ].compact
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
	    targ = {get_archive_path => get_files}
	    @pkg_task = ::Rant::Generators::SubFile.rant_gen(
		@rac, @ch, [basedir, targ].compact, &block)

	    @dist_dirname = File.split(name).last
	    @dist_dirname << "-#@version" if @version
	    @dist_root, = File.split path
	    @dist_path = (@dist_root == "." ?
		@dist_dirname : File.join(@dist_root, @dist_dirname))
	    dist_task = define_dist_dir_task
	    # the archive-creating task depends on the copying task
	    # (dist_task)
	    @pkg_task << dist_task

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
	    @dist_dir_task = cx.gen(Rant::Generators::Directory,
		    @dist_path => @res_files) { |t|
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

    # Use this class as a generator to create gzip compressed tar
    # archives.
    class Tgz < Base
	def initialize(*args)
	    super
	    @extension = ".tgz"
	end
	# Ensure to set #rac first.
	# Creates a file task wich invokes tar to create a tgz
	# archive. Returns the created task.
	def define_task
	    if ::Rant::Env.have_tar?
		define_tar_task
	    else
		define_minitar_task
	    end
	end
	def define_tar_task
	    define_cmd_task { |path, t|
		@rac.cx.sys "tar --files-from #{path} -czf #{t.name}"
	    }
	end
	def define_minitar_task
	    define_cmd_task do |path, t|
		begin
		    @rac.cx.sys.minitar_tgz t.name, @res_files
		rescue LoadError
		    @rac.abort_at @ch,
			"minitar not available. " +
			"Try to install with `gem install archive-tar-minitar'."
		end
	    end
	end
    end # class Tgz

    # Use this class as a generator to create zip archives.
    class Zip < Base
	def initialize(*args)
	    super
	    @extension = ".zip"
	end
	# Ensure to set #rac first.
	# Creates a file task wich invokes zip to create a zip
	# archive. Returns the created task.
	def define_task
	    if ::Rant::Env.have_zip?
		define_zip_task
	    else
		define_rubyzip_task
	    end
	end
	def define_zip_task
	    define_cmd_task { |path, t|
		cmd = "zip -@qyr #{t.name}"
		@rac.cmd_msg cmd
		IO.popen cmd, "w" do |z|
		    z.print IO.read(path)
		end
		raise Rant::CommandError.new(cmd, $?) unless $?.success?
	    }
	end
	def define_rubyzip_task
	    define_cmd_task do |path, t|
		begin
		    @rac.cx.sys.rubyzip t.name,
			@res_files, :recurse => true
		rescue LoadError
		    @rac.abort_at @ch,
			"rubyzip not available. " +
			"Try to install with `gem install rubyzip'."
		end
	    end
	end
    end # class Zip
end # module Rant::Generators::Archive

# The classes in this module act as generators which create archives.
# The difference to the Archive::* generators is, that the Package
# generators move all archive entries into a toplevel directory.
module Rant::Generators::Package
    class Tgz < Rant::Generators::Archive::Tgz
	def define_tar_task
	    define_task_for_dir do |t|
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		@rac.cx.sys %W(tar zcf #{fn} #@dist_dirname)
		Dir.chdir old_pwd
	    end
	end
	def define_minitar_task
	    define_task_for_dir do
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		begin
		    @rac.cx.sys.minitar_tgz fn, @dist_dirname
		rescue LoadError
		    @rac.abort_at @ch,
			"minitar not available. " +
			"Try to install with `gem install archive-tar-minitar'."
		ensure
		    Dir.chdir old_pwd
		end
	    end
	end
    end # class Tgz

    class Zip < Rant::Generators::Archive::Zip
	def define_zip_task
	    define_task_for_dir do
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		# zip options:
		#   y: store symlinks instead of referenced files
		#   r: recurse into directories
		#   q: quiet operation
		@rac.cx.sys %W(zip -yqr #{fn} #@dist_dirname)
		Dir.chdir old_pwd
	    end
	end
	def define_rubyzip_task
	    define_task_for_dir do
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		begin
		    @rac.cx.sys.rubyzip fn,
			@dist_dirname, :recurse => true
		rescue LoadError
		    @rac.abort_at @ch,
			"rubyzip not available. " +
			"Try to install with `gem install rubyzip'."
		ensure
		    Dir.chdir old_pwd
		end
	    end
	end
    end # class Zip
end # module Rant::Generators::Package
