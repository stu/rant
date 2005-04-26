
# clean.rb - "Clean" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'

class Rant::Generators::Clean
    def self.rant_generate(rac, ch, args, &block)
	# validate args
	if args.size > 1
	    rac.abort_at(ch, "Clean doesn't take more than one argument.")
	end
	tname = args.first || "clean"

	# set var with task name to a MultiFileList
	case rac.var[tname]
	when nil
	    rac.var[tname] = Rant::MultiFileList.new(rac)
	when Rant::RacFileList
	    ml = Rant::MultiFileList.new(rac)
	    rac.var[tname] = ml.add(rac.var[tname])
	when Rant::MultiFileList
	    # ok, nothing to do
	else
	    # TODO: refine error message
	    rac.abort_at(ch,
		"var `#{tname}' already exists.",
		"Clean uses var with the same name as the task name.")
	end

	# create task
	rac.task :__caller__ => ch, tname => [] do |t|
	    rac.var[tname].each_entry { |entry|
		if test ?e, entry
		    if test ?f, entry
			rac.cx.sys.rm_f entry
		    else
			rac.cx.sys.rm_rf entry
		    end
		end
	    }
	end
    end
end # class Rant::Generators::Clean
