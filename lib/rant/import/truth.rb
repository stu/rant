
#--
# truth.rb - Import truth into rant ;)
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module Worker
	def %(desc)
	    @description = case @description
	    when nil: desc
	    when /\n$/: @description + desc
	    else "#@description\n#{desc}"
	    end
	    self
	end
    end
    class RacFileList
	def %(fu_sym)
	    @rac.cx.sys.send(fu_sym, to_ary)
	end
    end
end
module RantContext
    def drag(name, *args, &block)
	import(name.to_s.downcase)
	gen(::Rant::Generators.const_get(name), *args, &block)
    end
end
