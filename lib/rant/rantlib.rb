
module Rant end

module Rant::Lib
    
    # Parses one string (elem) as it occurs in the array
    # which is returned by caller.
    # E.g.:
    #	p parse_caller_elem "/usr/local/lib/ruby/1.8/irb/workspace.rb:52:in `irb_binding'"
    # prints:
    #   {:method=>"irb_binding", :ln=>52, :file=>"/usr/local/lib/ruby/1.8/irb/workspace.rb"} 
    def parse_caller_elem elem
	parts = elem.split(":")
	rh = {	:file => parts[0],
		:ln => parts[1].to_i
	     }
	meth = parts[2]
	if meth && meth =~ /\`(\w+)'/
	    meth = $1
	end
	rh[:method] = meth
	rh
    end

    module_function :parse_caller_elem
end
