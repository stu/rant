
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

	class QueryError < Error
	end

	class Space

	    def initialize
		# holds all values
		@store = {}
		# holds constraints for values in @store
		@constraints = {}
	    end

	    def query(*args, &block)
		# currently ignoring block
		case args.size
		when 0
		    raise QueryError, "no arguments"
		when 1
		    arg = args.first
		    if Hash === arg
			set_all arg
		    else
			self[arg]
		    end
		else
		    raise QueryError, "to many arguments"
		end
	    end

	    # Get var with name +vid+.
	    def [](vid)
		@store[RantVar.valid_vid(vid)]
	    end

	    # Set var with name +vid+ to val. Throws a ConstraintError
	    # if +val+ doesn't match the constraint on +vid+ (if a
	    # constraint is registered for +vid+).
	    def []=(vid, val)
		vid = RantVar.valid_vid(vid)
		c = @constraints[vid]
		@store[vid] = c ? c.filter(val) : val
	    end

	    def set_all hash
		unless Hash === hash
		    raise QueryError,
			"set_all argument has to be a hash"
		end
		hash.each_pair { |k, v|
		    self[k] = v
		}
	    end

	    # Add +constraint+ for var with id +vid+.
	    def constrain vid, constraint
		vid = RantVar.valid_vid(vid)
		unless RantVar.valid_constraint? constraint
		    raise InvalidConstraintError, constraint
		end
		@constraints[vid] = constraint
	    end

	end	# class Space

	module Constraint
	end	# module Constraint

	# A +vid+ has to be a String to be valid.
	def valid_vid(obj)
	    case obj
	    when String: obj
	    when Symbol: obj.to_s
	    else
		if obj.respond_to? :to_str
		    obj.to_str
		else
		    raise InvalidVidError, obj
		end
	    end
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

	module_function :valid_constraint?, :valid_vid
    end	# module RantVar
end	# module Rant
