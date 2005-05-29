
# rubycmdwrapper.rb - "Win32::RubyCmdWrapper" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'

module Rant::Generators
    module Win32
	module RubyCmdWrapper
	    def self.rant_gen(rac, ch, args, &block)
		fl = args.first
		unless args.size == 1 and fl.respond_to? :to_ary
		    rac.abort_at(ch,
			"Win32::RubyCmdWrapper takes a list of filenames.")
		end
		if fl.respond_to? :exclude
		    fl.exclude "*.cmd"
		end
		fl = fl.to_ary
		cmd_files = fl.map { |f| f.sub_ext "cmd" }
		cmd_files.zip(fl).each { |cmd, bin|
		    # the .cmd file does not depend on the bin file
		    rac.cx.file cmd do |t|
			open(t.name, "w") { |f|
			    i_bin = File.join(::Rant::Env::RUBY_BINDIR,
				File.basename(bin))
			    rac.cmd_msg "Writing #{t.name}: #{i_bin}"
			    f.puts "@#{rac.cx.sys.sp ::Rant::Env::RUBY} #{rac.cx.sys.sp i_bin} %*"
			}
		    end
		}
		cmd_files
	    end
	end
    end
end
