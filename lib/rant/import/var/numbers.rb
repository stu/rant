
# numbers.rb - Constraints for numeric Rantfile variables.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module RantVar
	module Constraints

	    class Integer
		include Constraint

		class << self
		    def rant_constraint(range = nil)
			if range
			    IntegerInRange.new(range)
			else
			    self.new
			end
		    end
		end

		def filter(val)
		    Kernel::Integer(val)
		rescue
		    raise ConstraintError.new(self, val)
		end
		def default
		    0
		end
		def to_s
		    "integer"
		end
	    end

	    class IntegerInRange < Integer
		def initialize(range)
		    @range = range
		end
		def filter(val)
		    i = super
		    if @range === i
			i
		    else
			raise ConstraintError.new(self, val)
		    end
		end
		def default
		    @range.min
		end
		def to_s
		    super + " #{@range}"
		end
	    end

	    class Float
		include Constraint

		class << self
		    def rant_constraint(range = nil)
			if range
			    FloatInRange.new(range)
			else
			    self.new
			end
		    end
		end

		def filter(val)
		    Kernel::Float(val)
		rescue
		    raise ConstraintError.new(self, val)
		end
		def default
		    0.0
		end
		def to_s
		    "float"
		end
	    end

	    class FloatInRange < Float
		def initialize(range)
		    @range = range
		end
		def filter(val)
		    i = super
		    if @range === i
			i
		    else
			raise ConstraintError.new(self, val)
		    end
		end
		def default
		    @range.first
		end
		def to_s
		    super + " #{@range}"
		end
	    end
        end # module Constraints
    end # module RantVar
end # module Rant

class Range
    def rant_constraint
        case first
        when ::Integer
            Rant::RantVar::Constraints::IntegerInRange.new(self)
        when ::Float
            Rant::RantVar::Constraints::FloatInRange.new(self)
        else
            raise NotAConstraintFactoryError.new(self)
        end
    end
end
