
# lists.rb - Constraints for Rantfile list variables.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module RantVar
	module Constraints
	    class List
		include Constraint

		class << self
		    alias rant_constraint new
		end

		def filter(val)
		    if val.respond_to? :to_ary
			val.to_ary
		    else
			raise ConstraintError.new(self, val)
		    end
		end
		def default
		    []
		end
		def to_s
		    "list (Array)"
		end
	    end

	    Array = List
        end # module Constraints
    end # module RantVar
end # module Rant
