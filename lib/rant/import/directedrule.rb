
# directedrule.rb - "DirectedRule" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'

class Rant::Generators::DirectedRule
    def self.rant_generate(rac, ch, args, &block)
	unless args.size == 1
	    rac.abort_at(ch, "DirectedRule takes one arguments.")
	end
	h = args.first
	if h.respond_to? :to_hash
	    h = h.to_hash
	else
	    rac.abort_at(ch, "Argument has to be a hash.")
	end
	ts_h, dir_h = nil, nil
	h.each { |k, v| v.respond_to?(:to_ary) ?
	    dir_h = { k => v } :
	    ts_h = { k => v }
	}
	# TODO: check that ts_h.size and dir_h.size == 1
	target, source = nil, nil
	ts_h.each { |target, source| }
	target_dir, source_dirs = nil, nil
	dir_h.each { |target_dir, source_dirs| }
	if target_dir.respond_to? :to_str
	    target_dir = target_dir.to_str
	else
	    rac.abort_at(ch, "String required as target directory.")
	end
	if source_dirs.respond_to? :to_ary
	    source_dirs = source_dirs.to_ary
	elsif source_dirs.respond_to? :to_str
	    source_dirs = [source_dirs.to_str]
	else
	    rac.abort_at(ch,
		"List of strings or string required for source directories.")
	end
	target = ".#{target}" if Symbol === target
	source = ".#{source}" if Symbol === source
	if target.respond_to? :to_str
	    target = target.to_str
	else
	    rac.abort_at(ch, "target has to be a string")
	end
	if source.respond_to? :to_str
	    source = source.to_str
	else
	    rac.abort_at(ch, "source has to be a string or symbol")
	end
	blk = self.new(rac, ch, target_dir, source_dirs,
	    target, source, &block)
	blk.define_hook
	blk
    end
    def initialize(rac, ch, target_dir, source_dirs,
	    target, source, &block)
	@rac = rac
	@ch = ch
	@source_dirs = source_dirs
	@target_dir = target_dir
	# target should be a string (file extension)
	@target = target.sub(/^\./, '')
	@target_rx = /#{Regexp.escape(target)}$/o
	# source should be a string (file extension)
	@source = source.sub(/^\./, '')
	@esc_target_dir = Regexp.escape(target_dir)
	@block = block
    end
    def call(name)
	self[name]
    end
    def [](name)
	#puts "rule for #{name} ?"
	if name =~ /^#@esc_target_dir\//o && name =~ @target_rx
	    #puts "  matches"
	    fn = File.basename(name)
	    src_fn = fn.sub_ext(@source)
	    #puts "  source filename #{src_fn}"
	    src = nil
	    @source_dirs.each { |d|
		path = File.join(d, src_fn)
		#puts "  #{path} exist?"
		(src = path) && break if test(?e, path)
	    }
	    if src
		[@rac.file(:__caller__ => @ch, name => src, &@block)]
	    else
		nil
	    end
	else
	    nil
	end
    end
    def define_hook
	@rac.resolve_hooks << self
    end
    def each_target &block
	@rac.cx.sys["#@target_dir/*"].each { |entry|
	    yield entry if entry =~ @target_rx
	}
    end
    def candidates
	sources.map { |src|
	    File.join(@target_dir, File.basename(src).sub_ext(@target))
	}
    end
    def sources
	# TODO: returning a file list would be more efficient
	cl = []
	@source_dirs.each { |dir|
	    cl.concat(@rac.cx.sys["#{dir}/*.#@source"])
	}
	cl
    end
end # class Rant::Generators::DirectedRule
