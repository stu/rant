
# rantvar.rb - Support for the +var+ method in Rantfiles.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#
# This file provides support for the +var+ attribute of the Rant
# application (Rant::RantApp#var).

# Most constants (classes, modules etc.) of Rant live in this module,
# thus it acts as a namespace.
#
# If you're looking for general info about Rant, read the
# README[link:files/README.html].

module Rant

    # Those are the filenames for rantfiles.
    # Case matters!
    ROOT_RANTFILE = "root.rant"
    SUB_RANTFILE = "sub.rant"
    RANTFILES = [ "Rantfile", "rantfile", ROOT_RANTFILE ]
    
    # Names of plugins and imports for which code was loaded.
    # Files that where loaded with the `import' commant are directly
    # added; files loaded with the `plugin' command are prefixed with
    # "plugin/".
    CODE_IMPORTS = []
    
    class RantAbortException < StandardError
    end

    class RantDoneException < StandardError
    end

    class Error < StandardError
    end

    # This module is a namespace for generator classes.
    module Generators
    end

    module RantVar

	class Error < Rant::Error
	end

	class ConstraintError < Error

	    attr_reader :constraint, :val

	    def initialize(constraint, val, msg = nil)
		#super(msg)
		@msg = msg
		@constraint = constraint
		@val = val
	    end

	    def message
		# TODO: handle @msg
		val_desc = @val.inspect
		val_desc[7..-1] = "..." if val_desc.length > 10
		"#{val_desc} doesn't match constraint: #@constraint"
	    end
	end

	class NotAConstraintFactoryError < Error
	    attr_reader :obj
	    def initialize(obj, msg = nil)
		@msg = msg
		@obj = obj
	    end
	    def message
		# TODO: handle @msg
		obj_desc = @obj.inspect
		obj_desc[7..-1] = "..." if obj_desc.length > 10
		"#{obj_desc} is not a valid constraint factory"
	    end
	end

	class InvalidVidError < Error
	    def initialize(vid, msg = nil)
		@msg = msg
		@vid = vid
	    end
	    def message
		# TODO: handle @msg
		vid_desc = @vid.inspect
		vid_desc[7..-1] = "..." if vid_desc.length > 10
		"#{vid_desc} is not a valid var identifier"
	    end
	end

	class InvalidConstraintError < Error
	end

	class QueryError < Error
	end

	class Space

	    @@env_ref = Object.new

	    def initialize
		# holds all values
		@store = {}
		# holds constraints for values in @store
		@constraints = {}
		# set by default query
	    end

	    def query(*args, &block)
		# currently ignoring block
		case args.size
		when 0
		    raise QueryError, "no arguments", caller
		when 1
		    arg = args.first
		    if Hash === arg
			if arg.size == 1
			    arg.each { |k,v|
				self[k] = v if self[k].nil?
			    }
			    self
			else
			    init_all arg
			end
		    else
			self[arg]
		    end
		when 2, 3
		    vid, cf, val = *args
                    constrain vid,
                        get_factory(cf).rant_constraint
		    self[vid] = val if val
		else
		    raise QueryError, "too many arguments"
		end
	    end

	    def restrict vid, ct, *ct_args
		if vid.respond_to? :to_ary
		    vid.to_ary.each { |v| restrict(v, ct, *ct_args) }
		else
		    constrain vid,
			get_factory(ct).rant_constraint(*ct_args)
		end
		self
	    end

	    def get_factory id
		if String === id || Symbol === id
                    id = Constraints.const_get(id) rescue nil
		end
		unless id.respond_to? :rant_constraint
                    raise NotAConstraintFactoryError.new(id), caller
		end
		id
	    end
	    private :get_factory

	    # Get var with name +vid+.
	    def [](vid)
		vid = RantVar.valid_vid vid
		val = @store[vid]
		val.equal?(@@env_ref) ? ENV[vid] : val
	    end

	    # Set var with name +vid+ to val. Throws a ConstraintError
	    # if +val+ doesn't match the constraint on +vid+ (if a
	    # constraint is registered for +vid+).
	    def []=(vid, val)
		vid = RantVar.valid_vid(vid)
		c = @constraints[vid]
		if @store[vid] == @@env_ref
		    ENV[vid] = c ? c.filter(val) : val
		else
		    @store[vid] = c ? c.filter(val) : val
		end
	    end

	    # Use ENV instead of internal store for given vars.
	    # Probably useful for vars like CC, CFLAGS, etc.
	    def env(*vars)
		vars.flatten.each { |var|
		    vid = RantVar.valid_vid(var)
		    cur_val = @store[vid]
		    next if cur_val == @@env_ref
		    ENV[vid] = cur_val unless cur_val.nil?
		    @store[vid] = @@env_ref
		}
		nil
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

	    def init_all hash
		unless Hash === hash
		    raise QueryError,
			"init_all argument has to be a hash"
		end
		hash.each_pair { |k, v|
		    self[k] = v if self[k].nil?
		}
	    end

	    # Add +constraint+ for var with id +vid+.
	    def constrain vid, constraint
		vid = RantVar.valid_vid(vid)
		unless RantVar.valid_constraint? constraint
		    raise InvalidConstraintError, constraint
		end
		@constraints[vid] = constraint
		if @store.member? vid
		    begin
			val = @store[vid]
			@store[vid] = constraint.filter(@store[vid])
		    rescue
			@store[vid] = constraint.default
			raise ConstraintError.new(constraint, val)
		    end
		else
		    @store[vid] = constraint.default
		end
	    end

	    def has_var?(vid)
		!self[vid].nil?
	    end

            def _set(vid, val) #:nodoc:
                @store[vid] = val
            end

            def _get(vid) #:nodoc:
                @store[vid]
            end

            def _init(vid, val) #:nodoc:
                @store[vid] ||= val
            end

	end	# class Space

	module Constraint
	    def matches? val
		filter val
		true
	    rescue
		return false
	    end
	end

	# A +vid+ has to be a String to be valid.
	def valid_vid(obj)
	    case obj
	    when String then obj
	    when Symbol then obj.to_s
	    else
		if obj.respond_to? :to_str
		    obj.to_str
		else
		    raise InvalidVidError.new(obj)
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
	    obj.respond_to?(:filter) &&
		obj.respond_to?(:matches?) &&
		obj.respond_to?(:default)
	end

	module_function :valid_constraint?, :valid_vid

	module Constraints
	    class AutoList
		include Constraint
		class << self
		    alias rant_constraint new
		end
		def filter(val)
		    if val.respond_to? :to_ary
			val.to_ary
		    elsif val.nil?
			raise ConstraintError.new(self, val)
		    else
			[val]
		    end
		end
		def default
		    []
		end
		def to_s
		    "list or single, non-nil value"
		end
	    end
        end # module Constraints
    end # module RantVar
end # module Rant
