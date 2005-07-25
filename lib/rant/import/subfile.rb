
# subfile.rb - "SubFile" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'

class Rant::Generators::SubFile
    def self.rant_gen(rac, ch, args, &block)
	case args.size
	when 1
	    fine, basedir = args
	when 2
	    basedir, fine = args
	else
	    rac.abort_at(ch, "SubFile takes one or two arguments.")
	end
	deps = []
	if fine.respond_to? :to_hash
            # hash should contain only one element
	    fine = fine.to_hash
	    fine.each { |k, v|
		ch = v && next if k == :__caller__
		fine = k
                if Rant::FileList === v
                    deps = v.dup
		elsif v.respond_to? :to_ary
		    deps.concat(v.to_ary)
		else
		    deps << v
		end
	    }
	end
	path = basedir ? File.join(basedir, fine) : fine
	file_desc = rac.pop_desc
	rac.prepare_task({path => deps}, block, ch) { |name,pre,blk|
	    dir, file = File.split(fine.to_s)
	    dirp = basedir ? File.join(basedir, dir) : dir
	    unless dir == "."
                unless rac.tasks.include? dirp
		    if basedir
			::Rant::Generators::Directory.rant_gen(
			    rac, ch, [basedir, dir])
		    else
			::Rant::Generators::Directory.rant_gen(
			    rac, ch, [dir])
		    end
		end
                pre << dirp
	    end
	    rac.cx.desc file_desc
	    rac.node_factory.new_file(rac, name, pre, blk)
	}
    end
end
