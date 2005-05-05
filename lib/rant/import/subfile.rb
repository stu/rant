
# subfile.rb - "SubFile" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'

class Rant::Generators::SubFile
    def self.rant_generate(rac, ch, args, &block)
	unless args.size == 1
	    rac.abort_at(ch, "SubFile takes one argument.")
	end
	file_desc = rac.pop_desc
	rac.prepare_task(args.first, block, ch) { |name,pre,blk|
	    dir, file = File.split name
	    unless dir == "."
		dt = rac.resolve(dir)
		if dt.empty?
		    dt = rac.cx.gen(::Rant::Generators::Directory, dir)
		end
		pre << dt
	    end
	    rac.cx.desc file_desc
	    ::Rant::FileTask.new(rac, name, pre, &blk)
	}
    end
end
