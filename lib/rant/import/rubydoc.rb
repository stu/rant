
require 'rant/rantlib'

module Rant
    class Generators::RubyDoc

	class << self

	    def rant_generate(app, ch, args, &block)
		if !args || args.empty?
		    self.new(app, ch, &block)
		elsif args.size == 1
		    name, pre, file, ln = app.normalize_task_arg(args.first, ch)
		    self.new(app, ch, name, pre, &block)
		else
		    app.abort(app.pos_text(file, ln),
			"RubyDoc takes only one additional argument, " +
			"which should be like one given to the `task' command.")
		end
	    end
	end

	# Directory where (html) output goes to.
	# Defaults to "doc".
	attr_accessor :op_dir
	# Files and directories to document. Initialized to an array
	# with the single entry "lib" if a directory of this name
	# exists, or to an empty array otherwise.
	attr_accessor :files
	# List of other options. Initialized to and empty array.
	attr_accessor :opts

	# Print rdoc command if true. Defaults to false.
	attr_accessor :verbose

	# Task name of rdoc-task.
	attr_reader :name

	def initialize(app, ch, name = :doc, prerequisites = [], &block)
	    @name = name
	    @pre = prerequisites
	    @op_dir = "doc"
	    @files = test(?d, "lib") ? ["lib"] : []
	    @opts = []
	    @verbose = false

	    yield self if block_given?
	    app.var["gen-rubydoc-rdoc_opts"] = self.rdoc_opts.dup

	    @pre ||= []
	    @pre.concat(self.rdoc_source_deps)
	    index = self.op_html_index
	    # define task task with given name first, so that it takes
	    # any previously set description
	    t = app.task(:__caller__ => ch, @name => [])
	    # The task which will actually run rdoc.
	    t << app.file(:__caller__ => ch, index => @pre) { |t|
		# We delay the require of the RDoc code until it is
		# actually needed, so it will be only loaded if the
		# rdoc task has to be run.
		require 'rdoc/rdoc'
		args = self.rdoc_args
		app.cmd_msg "rdoc #{args.join(' ')}" if @verbose
		begin
		    RDoc::RDoc.new.document(args)
		rescue RDoc::RDocError => e
		    $stderr.puts e.message
		    t.fail
		end
	    }
	end

	# Get a list of all options as they would be given to +rdoc+
	# on the commandline.
	def rdoc_opts
	    optlist = []
	    optlist << "-o" << @op_dir if @op_dir
	    if @opts
		# validate opts
		case @opts
		when Array # ok, nothing to do
		when String
		    @opts = @opts.split
		else
		    if @opts.respond_to? :to_ary
			@opts = @opts.to_ary 
		    else
			raise RantfileException,
			    "RDoc options should be a string or a list of strings."
		    end
		end
		optlist.concat @opts
	    end
	    optlist
	end
	alias options rdoc_opts

	# Get a list with all arguments which would be given to rdoc
	# on the commandline.
	def rdoc_args
	    al = rdoc_opts
	    al.concat @files if @files
	    al
	end

	def op_html_index
	    File.join(@op_dir, "index.html")
	end

	def rdoc_source_deps
	    # TODO: optimize and refine
	    deps = []
	    @files.each { |e|
		if test(?d, e)
		    deps.concat Dir["#{e}/**/*.rb"]
		else
		    deps << e
		end
	    }
	    deps
	end
    end	# class Generators::RubyDoc
end	# module Rant
