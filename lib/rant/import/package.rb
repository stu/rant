
# package.rb - Rant packaging support.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'
require 'rant/import/subfile'

module Rant::Generators::Package
    class Base
	extend Rant::MetaUtils

	def self.rant_gen(rac, ch, args, &block)
	    if args.size < 1 || args.size > 2
		rac.abort_at(ch,
		    "#{self.class} takes one or two arguments.")
	    end
	    pkg_name, opts = args
	    pkg = self.new(pkg_name)
	    pkg.rac = rac
	    pkg.ch = ch
	    if opts
		if opts.respond_to? :to_hash
		    opts = opts.to_hash
		else
		    rac.abort_at(ch,
			"#{self.class}: second argument has to be a hash.")
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
			rac.warn_msg("#{self}: ignoring option #{k}")
		    end
		}
	    end
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

	# Path to archive without basedir.
	def get_archive_path
	    return @archive_path if @archive_path
	    path = name
	    path << "-#@version" if @version
	    path << @extension if @extension
	    @archive_path = path
	end

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
	    fl
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
	    targ[:__caller__] = @ch if @ch
	    args = [::Rant::Generators::SubFile, basedir, targ].compact
	    @pkg_task =
		@rac.cx.gen(*args) do |t|
		    with_manifest { |path| yield(path, t) }
		end
	end
    end # class Base

    class Tgz < Base
	def initialize(*args)
	    super
	    @extension = ".tgz"
	end
	# Ensure to set #rac first.
	# Creates a file task wich invokes tar to create a tgz
	# archive. Returns the created task.
	def define_task
	    define_cmd_task { |path, t|
		@rac.cx.sys "tar --files-from #{path} -czf #{t.name}"
	    }
	end
    end # class Tgz

    class Zip < Base
	def initialize(*args)
	    super
	    @extension = ".zip"
	end
	# Ensure to set #rac first.
	# Creates a file task wich invokes zip to create a zip
	# archive. Returns the created task.
	def define_task
	    define_cmd_task { |path, t|
		cmd = "zip -@qyr #{t.name}"
		@rac.cmd_msg cmd
		IO.popen cmd, "w" do |z|
		    z.print IO.read(path)
		end
	    }
	end
    end # class Zip
end # module Rant::Generators::Package
