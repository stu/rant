
require 'rant/rantlib'

class Rant::Generators::RubyPackage

    class << self
	def rant_gen(app, ch, args, &block)
	    if !args || args.empty?
		self.new(:app => app, :__caller__ => ch, &block)
	    elsif args.size == 1
		pkg_name = case args.first
		when String then  args.first
		when Symbol then args.first.to_s
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
                if val.respond_to? :to_ary
                    val = val.to_ary
                else
                    val = [val]
                end
                @data["#{a}"] = val
	    end
	EOM
    }

    def author=(author)
        @data["authors"] = author
    end

    # A hash containing all package information.
    attr_reader :data
    # Directory where packages go to. Defaults to "pkg".
    attr_accessor :pkg_dir

    def initialize(opts = {})
	@app = opts[:app] or raise ":app argument required"
	@pkg_dir = "pkg"
	@pkg_dir_task = nil
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
            if attr == "files"
                spec.send(setter, val.dup) if val
                next
            end
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
	@pkg_dir_task =
            Rant::Generators::Directory.rant_gen(@app, @ch, [@pkg_dir])
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
		require 'rubygems/package'
	    rescue LoadError => e
		t.fail "Couldn't load `rubygems'. " +
		    "Probably RubyGems isn't installed on your system."
	    end
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

            # fix for YAML bug in Ruby 1.8.3 and 1.8.4 previews
            #
            # Update: That's not a bug in YAML 1.8.3 and later, it's a
            # non-backwards compatible change, because YAML 1.8.2 and
            # later is buggy. (My current understanding of this
            # issue.) Adding the "---" at the start ensures that it
            # can be read with all Ruby YAML versions.
            if RUBY_VERSION > "1.8.2"
                def spec.to_yaml(*args, &block)
                    yaml = super
                    yaml =~ /^---/ ? yaml : "--- #{yaml}"
                end
            end

	    fn = nil
	    begin
		fn = Gem::Package.build(spec)
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
	    @app.cx.task({:__caller__ => @ch, tname => pkg_name})
	end
	# actual tar-creating task
        @app.cx.import "package/tgz"
        @tar_task =
        Rant::Generators::Package::Tgz.rant_gen(@app, @ch,
            ["#@pkg_dir/#{pkg_base_name}",
            # we use tar.gz extension here for backwards compatibility
            {:files => pkg_files, :extension => ".tar.gz"}])
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
        @app.cx.import "package/zip"
        @zip_task =
        Rant::Generators::Package::Zip.rant_gen(@app, @ch,
            ["#@pkg_dir/#{pkg_base_name}", {:files => pkg_files}])
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
	self.tar_task(nil)
	self.zip_task(nil)
	begin
	    require 'rubygems'
	    self.gem_task(nil)
	    defined = true
	rescue LoadError
	end
	true
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
