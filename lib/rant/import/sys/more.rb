
# more.rb - Experimental sys methods.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module Sys
        def write_to_file(fn, content)
            content = content.to_str
            fu_output_message "writing #{content.size} bytes to file `#{fn}'"
            File.open fn, "w" do |f|
                f.write content
            end
        end
        def clean(entry)
            if test ?f, entry
                rm_f entry
            elsif test ?e, entry
                rm_rf entry
            end
        end
    end # module Sys
end # module Rant
