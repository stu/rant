
require 'rant/rantlib'

class Rant::Generators::Package

    class << self
	def rant_generate(app, ch, args, &block)
	    if !args || args.empty?
		self.new(:app => app, :__caller__ => ch, &block)
	    elsif args.size == 1
		pkg_name = case args.first
		when String: args.first
		when Symbol: args.first.to_s
		else
		    app.abort("Package takes only one additional " +
			"argument, which should be a string or symbol.")
		end
		self.new(:app => app, :__caller__ => ch,
		    :name => pkg_name, &block)
	    else
		app.abort(app.pos_text(file, ln),
		    "Package takes only one additional argument, " +
		    "which should be a string or symbol.")
	    end
	end
    end

    # A hash containing all package information.
    attr_reader :data
    # Directory where packages go to. Defaults to "pkg".
    attr_accessor :pkg_dir

    def initialize(opts = {})
	@rac = opts[:app] || Rant.rantapp
	@pkg_dir = "pkg"
	@pkg_dir_task = nil
	@dist_dir_task = nil
	@tar_task = nil
	@zip_task = nil
	@package_task = nil
	name = opts[:name]
	@ch = opts[:__caller__] || Rant::Lib.parse_caller_elem(caller[0])
	unless name
	    # TODO: pos_text
	    @rac.warn_msg(@rac.pos_text(@ch[:file], @ch[:ln]),
		"No package name given, using directory name.")
	    # use directory name as project name
	    name = File.split(Dir.pwd)[1]
	    # reset name if it contains a slash or a backslash
	    name = nil if name =~ /\/|\\/
	end
	@data = { "name" => name }

	yield self if block_given?
    end

    def name
	@data["name"]
    end

    def version
	@data["version"]
    end

    def version=(str)
	unless String === str
	    @rac.abort_at(@ch, "version has to be a String")
	end
	@data["version"] = str
    end

    def files
	@data["files"]
    end

    def files=(list)
	unless Array === list || ::Rant::FileList === List
	    if list.respond_to? :to_ary
		list = list.to_ary
	    else
		@rac.abort_at(@ch,
		    "files must be an Array or FileList")
	    end
	end
	@data["files"] = list
    end

    def validate_attrs(pkg_type = :general)
	%w(name files).each { |a|
	    pkg_requires_attr a
	}
    end
    private :validate_attrs

    def pkg_requires_attr(attr_name)
	unless @data[attr_name]
	    @rac.abort("Packaged defined: " +
		@rac.pos_text(@ch[:file], @ch[:ln]),
		"`#{attr_name}' attribute required")
	end
    end

    def pkg_dir_task
	return if @pkg_dir_task
	if @dist_dir_task
	    # not ideal but should work: If only the gem task will
	    # be run, dist dir creation wouldn't be necessary
	    return @pkg_dir_task = @dist_dir_task
	end
	@pkg_dir_task = @rac.gen(
	    ::Rant::Generators::Directory, @pkg_dir)
    end

    def dist_dir_task
	return if @dist_dir_task
	pkg_name = pkg_dist_dir
	dist_dir = pkg_dist_dir
	@dist_dir_task = @rac.gen(Rant::Generators::Directory,
		dist_dir => files) { |t|
	    # ensure to create new and empty destination directory
	    if Dir.entries(dist_dir).size > 2	# "." and ".."
		@rac.sys.rm_rf(dist_dir)
		@rac.sys.mkdir(dist_dir)
	    end
	    # evaluate directory structure first
	    dirs = []
	    fl = []
	    files.each { |e|
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
		dest = File.join(dist_dir, dir)
		@rac.sys.mkpath(dest) unless test(?d, dest)
	    }
	    # link or copy files
	    fl.each { |f|
		dest = File.join(dist_dir, f)
		@rac.sys.safe_ln(f, dest)
	    }
	}
    end

    def tar_task(tname = :tar)
	validate_attrs
	# Create tar task first to ensure that a pending description
	# is used for the tar task and not for the dist dir task.
	pkg_name = tar_pkg_path
	pkg_files = files
	if tname
	    # shortcut task
	    @rac.task({:__caller__ => @ch, tname => pkg_name})
	end
	# actual tar-creating task
	@tar_task = @rac.file(:__caller__ => @ch,
		pkg_name => [pkg_dist_dir] + pkg_files) { |t|
	    @rac.sys.cd(@pkg_dir) {
		@rac.sys %W(tar zcf #{tar_pkg_name} #{pkg_base_name})
	    }
	}
	dist_dir_task
    end

    def zip_task(tname = :zip)
	validate_attrs
	# Create zip task first to ensure that a pending description
	# is used for the zip task and not for the dist dir task.
	pkg_name = zip_pkg_path
	pkg_files = files
	if tname
	    # shortcut task
	    @rac.task({:__caller__ => @ch, tname => pkg_name})
	end
	# actual zip-creating task
	@zip_task = @rac.file(:__caller__ => @ch,
		pkg_name => [pkg_dist_dir] + pkg_files) { |t|
	    @rac.sys.cd(@pkg_dir) {
		# zip options:
		#   y: store symlinks instead of referenced files
		#   r: recurse into directories
		#   q: quiet operation
		@rac.sys %W(zip -yqr #{zip_pkg_name} #{pkg_base_name})
	    }
	}
	dist_dir_task
    end

    # Create a task which runs gem/zip/tar tasks.
    def package_task(tname = :package)
	def_tasks = [@tar_task, @zip_task].compact
	if def_tasks.empty?
	    # take description for overall package task
	    pdesc = @rac.pop_desc
	    unless def_available_tasks
		@rac.desc pdesc
		@rac.warn_msg("No tools for packaging available (tar, zip):",
		    "Can't generate task `#{tname}'.")
		return
	    end
	    @rac.desc pdesc
	end
	pre = []
	pre << tar_pkg_path if @tar_task
	pre << zip_pkg_path if @zip_task
	pre << gem_pkg_path if @gem_task
	@rac.task(:__caller__ => @ch, tname => pre)
    end

    # Returns true if at least one task was defined.
    def def_available_tasks
	defined = false
	if Rant::Env.have_tar?
	    # we don't create shortcut tasks, hence nil as argument
	    self.tar_task(nil)
	    defined = true
	end
	if Rant::Env.have_zip?
	    self.zip_task(nil)
	    defined = true
	end
	defined
    end

    def pkg_base_name
	unless name
	    @rac.abort(@rac.pos_text(@ch[:file], @ch[:ln]),
		"`name' required for packaging")
	end
	version ? "#{name}-#{version}" : name
    end

    def tar_pkg_name
	pkg_base_name + ".tar.gz"
    end

    def tar_pkg_path
	pkg_dist_dir + ".tar.gz"
    end

    def zip_pkg_name
	pkg_base_name + ".zip"
    end

    def zip_pkg_path
	pkg_dist_dir + ".zip"
    end

    def pkg_dist_dir
	@pkg_dir ? File.join(@pkg_dir, pkg_base_name) : pkg_base_name
    end

end	# class Rant::Generators::Package
