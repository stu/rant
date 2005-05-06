
require 'rant/rantlib'

class Rant::Generators::RubyPackage

    class << self
	def rant_generate(app, ch, args, &block)
	    if !args || args.empty?
		self.new(:app => app, :__caller__ => ch, &block)
	    elsif args.size == 1
		pkg_name = case args.first
		when String: args.first
		when Symbol: args.first.to_s
		else
		    app.abort("RubyPackage takes only one additional " +
			"argument, which should be a string or symbol.")
		end
		self.new(:app => app, :__caller__ => ch,
		    :name => pkg_name, &block)
	    else
		app.abort(app.pos_text(file, ln),
		    "RubyPackage takes only one additional argument, " +
		    "which should be a string or symbol.")
	    end
	end
    end

    # Attributes with a single value.
    PACKAGE_SINGLE_ATTRS = [
	"name",
	"date",
	"description",
	"email",
	"has_rdoc",
	"homepage",
	"platform",
	"required_ruby_version",
	"rubyforge_project",
	"summary",
	"version",
    ]

    # These attributes may be set to a single value, which will be
    # converted to an array with a single element.
    PACKAGE_TO_LIST_ATTRS = [
	"author",
	"bindir",
	"executable",
	"extension",
	"files",
	"rdoc_options",
	"requires",
	"test_files",
	"test_suite",
    ]

    PACKAGE_ATTRS = PACKAGE_SINGLE_ATTRS + PACKAGE_TO_LIST_ATTRS

    EXPLICIT_GEM_MAPPING = {
	"executable" => "executables",
	"requires" => "requirements",
	# add requires => requirements ?
    }

    PACKAGE_NO_VAL = Object.new

    PACKAGE_SINGLE_ATTRS.each { |a|
	eval <<-EOM, binding
	    def #{a}(val = PACKAGE_NO_VAL)
		if val.equal? PACKAGE_NO_VAL
		    @data["#{a}"]
		else
		    self.#{a} = val
		end
	    end
	    def #{a}=(val)
		@data["#{a}"] = val
	    end
	EOM
    }
    PACKAGE_TO_LIST_ATTRS.each { |a|
	eval <<-EOM, binding
	    def #{a}(val0 = PACKAGE_NO_VAL, *args)
		if val0.equal? PACKAGE_NO_VAL
		    @data["#{a}"]
		else
		    self.#{a} = [val0, *args].flatten
		end
	    end
	    def #{a}=(val)
		unless val.nil? || Array === val
		    if val.respond_to? :to_ary
			val = val.to_ary
		    else
			val = [val]
		    end
		end
		@data["#{a}"] = val
	    end
	EOM
    }

    # A hash containing all package information.
    attr_reader :data
    # Directory where packages go to. Defaults to "pkg".
    attr_accessor :pkg_dir

    def initialize(opts = {})
	@app = opts[:app] || Rant.rantapp
	@pkg_dir = "pkg"
	@pkg_dir_task = nil
	@dist_dir_task = nil
	@gem_task = nil
	@tar_task = nil
	@zip_task = nil
	@package_task = nil
	name = opts[:name]
	@ch = opts[:__caller__] || Rant::Lib.parse_caller_elem(caller[0])
	unless name
	    # TODO: pos_text
	    @app.warn_msg(@app.pos_text(@ch[:file], @ch[:ln]),
		"No package name given, using directory name.")
	    # use directory name as project name
	    name = File.split(Dir.pwd)[1]
	    # reset name if it contains a slash or a backslash
	    name = nil if name =~ /\/|\\/
	end
	@data = { "name" => name }

	yield self if block_given?
    end

    def method_missing(sym, *args)
	super unless args.size == 1
	a = sym.to_s
	if a =~ /^gem_([^=]+)=$/
	    @data["gem-#$1"] = args.first
	else
	    super
	end
    end

    def validate_attrs(pkg_type = :general)
	%w(name files).each { |a|
	    pkg_requires_attr a
	}
	case pkg_type
	when :gem
	    %w(version summary).each { |a|
		gem_requires_attr a
	    }
	end
    end
    private :validate_attrs

    def gem_requires_attr(attr_name)
	unless @data[attr_name] || @data["gem-#{attr_name}"]
	    @app.abort("RubyPackaged defined: " +
		@app.pos_text(@ch[:file], @ch[:ln]),
		"gem specification requires `#{attr_name}' attribute")
	end
    end

    def pkg_requires_attr(attr_name)
	unless @data[attr_name]
	    @app.abort("RubyPackaged defined: " +
		@app.pos_text(@ch[:file], @ch[:ln]),
		"`#{attr_name}' attribute required")
	end
    end

    def map_to_gemspec spec
	mapped_attrs = []
	# Map attributes from data to the gem spec as explicitely
	# specified.
	EXPLICIT_GEM_MAPPING.each_pair { |attr, gem_attr|
	    setter = "#{gem_attr}="
	    if @data.key? attr
		mapped_attrs << attr
		spec.send setter, @data[attr]
	    end
	}
	# Try to map other attributes.
	@data.each_pair { |attr, val|
	    next if attr =~ /^gem\-./
	    next if mapped_attrs.include? attr
	    setter = "#{attr}="
	    spec.send(setter, val) if spec.respond_to? setter
	}
	# `gem-' attributes override others for gem spec
	@data.each_pair { |attr, val|
	    if attr =~ /^gem\-(.+)$/
		spec.send("#$1=", val)
	    end
	}
    end
    private :map_to_gemspec

    def pkg_dir_task
	return if @pkg_dir_task
	if @dist_dir_task
	    # not ideal but should work: If only the gem task will
	    # be run, dist dir creation wouldn't be necessary
	    return @pkg_dir_task = @dist_dir_task
	end
	@pkg_dir_task = @app.gen(Rant::Generators::Directory, @pkg_dir)
    end

    def dist_dir_task
	return if @dist_dir_task
	pkg_name = pkg_dist_dir
	dist_dir = pkg_dist_dir
	@dist_dir_task = @app.gen(Rant::Generators::Directory,
		dist_dir => files) { |t|
	    # ensure to create new and empty destination directory
	    if Dir.entries(dist_dir).size > 2	# "." and ".."
		@app.sys.rm_rf(dist_dir)
		@app.sys.mkdir(dist_dir)
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
		@app.sys.mkpath(dest) unless test(?d, dest)
	    }
	    # link or copy files
	    fl.each { |f|
		dest = File.join(dist_dir, f)
		@app.sys.safe_ln(f, dest)
	    }
	}
    end

    # Create task for gem building. If tname is a true value, a
    # shortcut-task will be created.
    def gem_task(tname = :gem)
	validate_attrs(:gem)
	# We first define the task to create the gem, and afterwards
	# the task to create the pkg directory to ensure that a
	# pending description is used to describe the gem task.
	pkg_name = gem_pkg_path
	if tname
	    # shortcut task
	    @app.task({:__caller__ => @ch, tname => pkg_name})
	end
	# actual gem-creating task
	@gem_task = @app.file({:__caller__ => @ch,
		pkg_name => [@pkg_dir] + files}) { |t|
	    # We require rubygems as late as possible to save some
	    # execution cycles if possible ;)
	    begin
		require 'rubygems'
	    rescue LoadError => e
		t.fail "Couldn't load `rubygems'. " +
		    "Probably RubyGems isn't installed on your system."
	    end
	    Gem.manage_gems
	    # map rdoc options from application vars
	    @data["rdoc_options"] ||= @app.var[:rubydoc_opts]
	    if @data["rdoc_options"]
		# remove the --op option, otherwise rubygems will
		# install the rdoc in the wrong directory (at least as
		# of version 0.8.6 of rubygems)
		@data["rdoc_options"] = without_rdoc_op_opt(@data["rdoc_options"])
		# automatically set "has_rdoc" to true unless it was
		# explicitely set to false (but if someone sets
		# options for rdoc, he probably wants to run rdoc...)
		@data["has_rdoc"] = true if @data["has_rdoc"].nil?
	    end
	    spec = Gem::Specification.new do |s|
		map_to_gemspec(s)
	    end
	    fn = nil
	    begin
		fn = Gem::Builder.new(spec).build
	    rescue Gem::InvalidSpecificationException => e
		t.fail "Invalid Gem specification: " + e.message
	    rescue Gem::Exception => e
		t.fail "Gem error: " + e.message
	    end
	    @app.sys.mv(fn, @pkg_dir) if @pkg_dir
	}
	pkg_dir_task
    end

    def tar_task(tname = :tar)
	validate_attrs
	# Create tar task first to ensure that a pending description
	# is used for the tar task and not for the dist dir task.
	pkg_name = tar_pkg_path
	pkg_files = files
	if tname
	    # shortcut task
	    @app.task({:__caller__ => @ch, tname => pkg_name})
	end
	# actual tar-creating task
	@tar_task = @app.file(:__caller__ => @ch,
		pkg_name => [pkg_dist_dir] + pkg_files) { |t|
	    @app.sys.cd(@pkg_dir) {
		@app.sys %W(tar zcf #{tar_pkg_name} #{pkg_base_name})
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
	    @app.task({:__caller__ => @ch, tname => pkg_name})
	end
	# actual zip-creating task
	@zip_task = @app.file(:__caller__ => @ch,
		pkg_name => [pkg_dist_dir] + pkg_files) { |t|
	    @app.sys.cd(@pkg_dir) {
		# zip options:
		#   y: store symlinks instead of referenced files
		#   r: recurse into directories
		#   q: quiet operation
		@app.sys %W(zip -yqr #{zip_pkg_name} #{pkg_base_name})
	    }
	}
	dist_dir_task
    end

    # Create a task which runs gem/zip/tar tasks.
    def package_task(tname = :package)
	def_tasks = [@gem_task, @tar_task, @zip_task].compact
	if def_tasks.empty?
	    # take description for overall package task
	    pdesc = @app.pop_desc
	    unless def_available_tasks
		@app.desc pdesc
		@app.warn_msg("No tools for packaging available (tar, zip, gem):",
		    "Can't generate task `#{tname}'.")
		return
	    end
	    @app.desc pdesc
	end
	pre = []
	pre << tar_pkg_path if @tar_task
	pre << zip_pkg_path if @zip_task
	pre << gem_pkg_path if @gem_task
	@app.task(:__caller__ => @ch, tname => pre)
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
	begin
	    require 'rubygems'
	    self.gem_task(nil)
	    defined = true
	rescue LoadError
	end
	defined
    end

    def pkg_base_name
	unless name
	    @app.abort(@app.pos_text(@ch[:file], @ch[:ln]),
		"`name' required for packaging")
	end
	version ? "#{name}-#{version}" : name
    end

    def gem_pkg_path
	pkg_dist_dir + ".gem"
    end

    #--
    # Arghhh... tar makes me feel angry
    #++

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

    # Remove -o and --op options from rdoc arguments.
    # Note that this only works if -o isn't part of an argument with
    # multiple one-letter options!
    def without_rdoc_op_opt(rdoc_args)
	last_was_op = false
	rdoc_args.reject { |arg|
	    if last_was_op
		last_was_op = false
		next true
	    end
	    case arg
	    when /^(-o|--op)$/
		last_was_op = true
		true
	    when /^-o./
		true
	    else
		false
	    end
	}
    end

end	# class Rant::Generators::RubyPackage
