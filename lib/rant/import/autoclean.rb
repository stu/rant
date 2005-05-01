
# autoclean.rb - "AutoClean" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'
require 'rant/import/clean'

class Rant::Generators::AutoClean
    def self.rant_generate(rac, ch, args, &block)
	# validate args
	if args.size > 1
	    rac.abort_at(ch,
		"AutoClean doesn't take more than one argument.")
	end
	tname = args.first || "autoclean"

	# we generate a normal clean task too, so that the user can
	# add files to clean via a var
	::Rant::Generators::Clean.rant_generate(rac, ch, [tname])

	# create task
	rac.task :__caller__ => ch, tname => [] do |t|
	    rac.tasks.each { |n, worker|
		worker.each_target { |entry|
		    if test ?e, entry
			if test ?f, entry
			    rac.cx.sys.rm_f entry
			else
			    rac.cx.sys.rm_rf entry
			end
		    end
		}
	    }
	end
    end
end
