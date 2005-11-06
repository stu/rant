
# booleans.rb - Constraints for Rantfile boolean variables.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module RantVar
	module Constraints
	    class Bool
		include Constraint
		class << self
		    alias rant_constraint new
		end
		def filter(val)
		    if ::Symbol === val or ::Integer === val
			val = val.to_s
		    end
		    if val == true
			true
		    elsif val == false || val == nil
			false
		    elsif val.respond_to? :to_str
			case val.to_str
			when /^\s*true\s*$/i:	true
			when /^\s*false\s*$/i:	false
			when /^\s*y(es)?\s*$/i:	true
			when /^\s*n(o)?\s*$/:	false
			when /^\s*on\s*$/i:	true
			when /^\s*off\s*$/i:	false
			when /^\s*1\s*$/:	true
			when /^\s*0\s*$/:	false
			else
			    raise ConstraintError.new(self, val)
			end
		    else
			raise ConstraintError.new(self, val)
		    end
		end
		def default
		    false
		end
		def to_s
		    "bool"
		end
	    end

	    class BoolTrue < Bool
		def default
		    true
		end
	    end

	    #--
	    # perhaps this should stay a secret ;)
	    #++
	    def true.rant_constraint
		BoolTrue.rant_constraint
	    end
	    def false.rant_constraint
		Bool.rant_constraint
	    end

        end # module Constraints
    end # module RantVar
end # module Rant
