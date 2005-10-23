
# metautils.rb - Meta programming utils for Rant internals.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module MetaUtils
	# Creates three accessor methods:
	#    obj.attr_name::	Return value of instance variable
	#			@attr_name
	#    obj.attr_name = val::	Set value instance variable
	#				@attr_name to val
	#    obj.attr_name val::	same as above
	def rant_attr attr_name
	    attr_name = valid_attr_name attr_name
	    attr_writer attr_name
	    module_eval <<-EOD
		def #{attr_name} val=Rant.__rant_no_value__
		    if val.equal? Rant.__rant_no_value__
			@#{attr_name}
		    else
			@#{attr_name} = val
		    end
		end
	    EOD
	    nil
	end
        # Creates three accessor methods:
        #   obj.attr_name?::    Return value, true or false
        #   obj.attr_name::     Set attribute to true
        #   obj.no_attr_name::  Set attribute to false
        def rant_flag attr_name
            attr_name = valid_attr_name attr_name
            module_eval <<-EOD
                def #{attr_name}?
                    @#{attr_name}
                end
                def #{attr_name}
                    @#{attr_name} = true
                end
                def no_#{attr_name}
                    @#{attr_name} = false
                end
            EOD
        end
	# Creates accessor methods like #rant_attr for the attribute
	# attr_name. Additionally, values are converted with to_str
	# before assignment to instance variables happens.
	def string_attr attr_name
	    attr_name = valid_attr_name attr_name
	    module_eval <<-EOD
		def #{attr_name}=(val)
		    if val.respond_to? :to_str
			@#{attr_name} = val.to_str
		    else
			raise ArgumentError,
			    "string (#to_str) value required", caller
		    end
		end
		def #{attr_name} val=Rant.__rant_no_value__
		    if val.equal? Rant.__rant_no_value__
			@#{attr_name}
		    else
			self.__send__(:#{attr_name}=, val)
		    end
		end
	    EOD
	    nil
	end
        def redirect_accessor(receiver, *attributes)
            redirect_reader(receiver, *attributes)
            redirect_writer(receiver, *attributes)
        end
        # Create attribute reader methods that redirect to the entity
        # given as first argument (e.g. an instance variable name).
        def redirect_reader(receiver, *attributes)
            attributes.each { |attr_name|
                attr_name = valid_attr_name attr_name
                module_eval <<-EOD
                    def #{attr_name}; #{receiver}.#{attr_name}; end
                EOD
            }
            nil
        end
        # Create attribute writer methods that redirect to the entity
        # given as first argument (e.g. an instance variable name).
        def redirect_writer(receiver, *attributes)
            attributes.each { |attr_name|
                attr_name = valid_attr_name attr_name
                module_eval <<-EOD
                    def #{attr_name}=(val); #{receiver}.#{attr_name}=
                        val; end
                EOD
            }
            nil
        end
        def redirect_message(receiver, *messages)
            messages.each { |message|
                module_eval <<-EOD
                    def #{message}(*args, &blk)
                        # the first ; on the next line is needed
                        # because of rant-import
                        ;#{receiver}.#{message}(*args, &blk)
                    end
                EOD
            }
            nil
        end
	# attr_name is converted to a string with #to_s and has to
	# match /^\w+$/. Returns attr_name.to_s.
	def valid_attr_name attr_name
	    attr_name = attr_name.to_s
	    attr_name =~ /^\w+\??$/ or
		raise ArgumentError,
		    "argument has to match /^\w+\??$/", caller
	    attr_name
	end
    end # module MetaUtils
end # module Rant
