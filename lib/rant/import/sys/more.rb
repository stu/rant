
# more.rb - Experimental sys methods.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module Sys
        def write_to_file(fn, content)
            fu_output_message "writing to file `#{fn}'"
            open fn, "w" do |f|
                f.write content
            end
        end
    end # module Sys
end # module Rant
