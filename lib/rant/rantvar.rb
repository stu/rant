
# This file provides support for the +var+ attribute of the Rant
# application (Rant::RantApp#var).

module Rant
    module RantVar

	class Error < StandardError
	end

	class ConstraintError < Error
	end

	class InvalidVidError < Error
	end

	class InvalidConstraintError < Error
	end

	class Space

	    def initialize
		# holds all values
		@store = {}
		# holds constraints for values in @store
		@constraints = {}
	    end

	    # Get var with name +vid+.
	    def [](vid)
		unless RantVar.valid_vid? vid
		    raise InvalidVidError, vid 
		end
		@store[vid]
	    end

	    # Set var with name +vid+ to val. Throws a ConstraintError
	    # if +val+ doesn't match the constraint on +vid+ (if a
	    # constraint is registered for +vid+).
	    def []=(vid, val)
		unless RantVar.valid_vid? vid
		    raise InvalidVidError, vid 
		end
		c = @constraints[vid]
		@store[vid] = c ? c.filter(val) : val
	    end

	    # Add +constraint+ for var with id +vid+.
	    def constrain vid, constraint
		unless RantVar.valid_vid? vid
		    raise InvalidVidError, vid 
		end
		unless RantVar.valid_constraint? constraint
		    raise InvalidConstraintError, constraint
		end
		@constraints[vid] = constraint
	    end

	end	# class Space

	module Constraint
	end	# module Constraint

	# A +vid+ has to be a String to be valid.
	def valid_vid?(obj)
	    String === obj
	end
	
	# A constraint has to respond to the following methods:
	# [filter(val)]
	#   Filter _val_ or throw ConstraintError if _val_ doesn't
	#   match constraint.
	# [matches?(val)]
	#   Return true if _val_ matches constraint.
	def valid_constraint?(obj)
	    # TODO: check for arity
	    obj.respond_to?(:filter) && obj.respond_to?(:matches?)
	end

	module_function :valid_constraint?, :valid_vid?
    end	# module RantVar
end	# module Rant
