
require 'rant/rantlib'

=begin
class Rant::MethodRecorder
    ACCEPT_ALL_BLOCK = lambda { true }
    def intialize(&accept)
	@ml = []
	@accept = &accept || ACCEPT_ALL_BLOCK
    end
    def method_missing(sym, *args)
	if @accept.call(sym, args)
	    @ml << [sym, args]
	else
	    super
	end
    end
end
=end

class Rant::RubyPackage

    class << self
	def rant_generate(app, ch, args, &block)
	    if !args || args.empty?
		self.new(:app => app, :__caller__ => ch, &block)
	    elsif args.size == 1
		pkg_name = case args.first
		when String: args.first
		when Symbol: args.first.to_s
		else
		    app.abort("RubyDoc takes only one additional " +
			"argument, which should be a string or symbol.")
		end
		self.new(:app => app, :__caller__ => ch,
		    :name => pkg_name, &block)
	    else
		app.abort(app.pos_text(file, ln),
		    "RubyDoc takes only one additional argument, " +
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
	"requires",
	"test_files",
	"test_suites",
    ]

    PACKAGE_ATTRS = PACKAGE_SINGLE_ATTRS + PACKAGE_TO_LIST_ATTRS

    EXPLICIT_GEM_MAPPING = {
	"executable" => "executables"
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
		    val = [val]
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
	@pkg_dir_task_defined = false
	name = opts[:name]
	@ch = opts[:__caller__] || Rant::Lib.parse_caller_elem(caller[0])
	unless name
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
	if a =~ /^gem_([^=])=$/
	    @data["gem-#$1"] = args.first
	else
	    super
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

    def pkg_dir_task
	return if @pkg_dir_task_defined
	@app.gen(Rant::Generators::Directory, @pkg_dir)
	@pkg_dir_task_defined = true
    end

    # Create task for gem building.
    def gem_task(tname = :gem)
	pkg_dir_task
	pkg_name = gem_pkg_name
	# shortcut task
	@app.task({:__caller__ => @ch, tname => pkg_name})
	# actual gem-creating task
	@app.file({:__caller__ => @ch,
		pkg_name => [@pkg_dir] + files}) { |t|
	    # We require rubygems as late as possible to save some
	    # execution cycles if possible ;)
	    begin
		require 'rubygems'
	    rescue LoadError => e
		t.fail "Couldn't load `rubygems'. " +
		    "Probably RubyGems isn't installed on your system."
	    end
	    spec = Gem::Specification.new
	    map_to_gemspec(spec)
	    Gem.manage_gems
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
    end

    def gem_pkg_name
	unless name
	    @app.abort(@app.pos_text(@ch[:file], @ch[:ln]),
		"`name' required for packaging")
	end
	pkg_name = @pkg_dir ? File.join(@pkg_dir, name) : name
	pkg_name << "-#{version}" if version
	pkg_name + ".gem"
    end

end	# class Rant::RubyPackage
