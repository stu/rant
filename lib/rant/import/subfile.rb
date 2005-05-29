
# subfile.rb - "SubFile" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'

class Rant::Generators::SubFile
    def self.rant_gen(rac, ch, args, &block)
	case args.size
	when 1
	    basedir, fine = nil, args.first
	    path = fine
	when 2
	    basedir, fine = args
	    path = File.join(basedir, fine)
	else
	    rac.abort_at(ch, "SubFile takes one or two arguments.")
	end
	file_desc = rac.pop_desc
	rac.prepare_task(path, block, ch) { |name,pre,blk|
	    dir, file = File.split(fine.to_s)
	    dirp = basedir ? File.join(basedir, dir) : dir
	    unless dir == "."
		dt = rac.resolve(dirp)
		if dt.empty?
		    dt = [if basedir
			rac.cx.gen(
			    ::Rant::Generators::Directory, basedir, dir)
		    else
			rac.cx.gen(
			    ::Rant::Generators::Directory, dir)
		    end]
		end
		pre.concat(dt)
	    end
	    rac.cx.desc file_desc
	    ::Rant::FileTask.new(rac, name, pre, &blk)
	}
    end
end
