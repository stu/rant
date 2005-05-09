
# include.rb - Support for C - parsing #include statements.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant end
module Rant::C
    module Include
	# Searches for all `#include' statements in the C/C++ source
	# from the string +src+.
	#
	# Returns two arguments:
	# 1. A list of all standard library includes (e.g. #include <stdio.h>).
	# 2. A list of all local includes (e.g. #include "stdio.h").
	def parse_includes(src)
	    if src.respond_to? :to_str
		src = src.to_str
	    else
		raise ArgumentError, "src has to be a string"
	    end
	    s_includes = []
	    l_includes = []
	    in_block_comment = false
	    prev_line = nil
	    src.each { |line|
		line.chomp!
		if prev_line
		    line = prev_line << line
		    prev_line = nil
		end
		if line =~ /\\$/
		    prev_line = line.chomp[0...line.length-1]
		end
		if in_block_comment
		    in_block_comment = false if line =~ %r|\*/|
		    next
		end
		case line
		when /\s*#\s*include\s+"([^"]+)"/
		    l_includes << $1
		when /\s*#\s*include\s+<([^>]+)>/
		    s_includes << $1
		when %r|(?!//)[^/]*/\*|
		    in_block_comment = true
		end
	    }
	    [s_includes, l_includes]
	end
	module_function :parse_includes
    end # module Include
end # module Rant::C
