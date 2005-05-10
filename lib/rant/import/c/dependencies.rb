
# dependencies.rb - C::Dependencies generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'
require 'rant/c/include'

module Rant::Generators::C end
class Rant::Generators::C::Dependencies
    def self.rant_generate(rac, ch, args, &block)
	c_files, out_fn, include_pathes = nil
	# args validation
	if block
	    rac.warn_msg "C::Dependencies: ignoring block"
	end
	case args.size
	when 0 # noop
	when 1
	    out_fn = args.first
	when 2
	    out_fn = args.first
	    opts = args[1]
	    if opts.respond_to? :to_hash
		opts = opts.to_hash
	    else
		rac.abort_at(ch,
		    "C::Dependencies: second argument has to be a hash.")
	    end
	    opts.each { |k, v|
		case k
		when :sources
		    c_files = v
		when :search, :search_pathes, :include_pathes
		    include_pathes = v
		else
		    rac.abort_at(ch,
			"C::Dependencies: no such option -- #{k}")
		end
	    }
	else
	    rac.abort_at(ch,
		"C::Dependencies takes one or two arguments.")
	end
	out_fn ||= "c_dependencies"
	c_files ||= rac.cx.sys["**/*.{c,cpp,cc,h,hpp}"]
	include_pathes ||= ["."]
	if out_fn.respond_to? :to_str
	    out_fn = out_fn.to_str
	else
	    rac.abort_at(ch, "filename has to be a string")
	end
	unless ::Rant::FileList === c_files
	    if c_files.respond_to? :to_ary
		c_files = c_files.to_ary
	    else
		rac.abort_at(ch, "sources has to be a list of files")
	    end
	end
	unless ::Rant::FileList === include_pathes
	    if include_pathes.respond_to? :to_ary
		include_patehs = include_pathes.to_ary
	    else
		rac.abort_at(ch,
		    "search has to be a list of directories")
	    end
	end
	# define file task
	rac.cx.file({:__caller__ => ch, out_fn => c_files}) do |t|
	    tmp_rac = ::Rant::RantApp.new
	    depfile_ts = Time.at(0)
	    if File.exist? t.name
		tmp_rac.source(t.name)
		depfile_ts = File.mtime(t.name)
	    end
	    rf_str = ""
	    c_files.each { |cf|
		f_task = nil
		unless test(?f, cf)
		    rac.warn_msg "#{t.name}: no such file -- #{cf}"
		    next
		end
		f_task = tmp_rac.tasks[cf.to_str]
		deps = f_task ? f_task.prerequisites : nil
		if !deps or File.mtime(cf) > depfile_ts
		    rac.cmd_msg "parsing #{cf}"
		    std_includes, local_includes = 
			::Rant::C::Include.parse_includes(File.read(cf))
		    deps = []
		    (std_includes + local_includes).each { |fn|
			path = existing_file(include_pathes, fn)
			deps << path if path
		    }
		end
		rf_str << file_deps(cf, deps) << "\n"
	    }
	    rac.cmd_msg "writing C source dependencies to #{t.name}"
	    open(t.name, "w") { |f|
		f.puts
		f.puts "# #{t.name}"
		f.puts "# C source dependencies generated by Rant #{Rant::VERSION}"
		f.puts "# WARNING: Modifications to this file will get lost!"
		f.puts
		f.write rf_str
	    }
	end
    end
    def self.existing_file(dirs, fn)
	dirs.each { |dir|
	    path = dir == "." ? fn : File.join(dir, fn)
	    return path if test ?f, path
	}
	nil
    end
    def self.file_deps(target, deps)
	s = "file #{target.to_str.inspect} => "
	s << "[#{ deps.map{ |fn| fn.to_str.inspect }.join(', ')}]"
	s << " do |t|\n"
	s << "    sys.touch t.name\n"
	s << "end\n"
    end
end # class Rant::Generators::C::Dependencies
