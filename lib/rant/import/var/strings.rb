
# strings.rb - Constraints for Rantfile string variables.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module RantVar
	module Constraints
	    class String
		include Constraint

		class << self
		    alias rant_constraint new
		end

		def filter(val)
		    if val.respond_to? :to_str
			val.to_str
		    elsif Symbol === val
			val.to_s
		    else
			raise ConstraintError.new(self, val)
		    end
		end
		def default
		    ""
		end
		def to_s
		    "string"
		end
	    end

	    class ToString < String
		class << self
		    alias rant_constraint new
		end
		def filter(val)
		    val.to_s
		end
	    end
        end # module Constraints
    end # module RantVar
end # module Rant
