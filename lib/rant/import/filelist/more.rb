
# more.rb - More Rant::FileList methods.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    class FileList
	# Remove all files which have the given name.
	def no_file(name)
            @actions << [:apply_ary_method, :reject!,
                lambda { |entry|
                    entry == name && !@keep[entry] && test(?f, entry)
                }]
	    @pending = true
	    self
	end

	# Remove all entries which contain an element
	# with the given suffix.
	def no_suffix(suffix)
	    @actions << [:no_suffix, suffix]
	    @pending = true
	    self
	end

	def apply_no_suffix(suffix)
	    elems =  nil
	    elem = nil
	    @files.reject! { |entry|
		elems = Sys.split_all(entry)
		elems.any? { |elem|
		    elem =~ /#{suffix}$/ && !@keep[entry]
		}
	    }
	end
	private :apply_no_suffix

	# Remove all entries which contain an element
	# with the given prefix.
	def no_prefix(prefix)
	    @actions << [:no_prefix, prefix]
	    @pending = true
	    self
	end

	def apply_no_prefix(prefix)
	    elems = elem = nil
	    @files.reject! { |entry|
		elems = Sys.split_all(entry)
		elems.any? { |elem|
		    elem =~ /^#{prefix}/ && !@keep[entry]
		}
	    }
	end
	private :apply_no_prefix
    end # class FileList
end # module Rant
