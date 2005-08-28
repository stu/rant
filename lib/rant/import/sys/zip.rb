
# zip.rb - +sys+ methods for zip archiving.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

#require 'rant/archive/rubyzip' #rant-import:uncomment

module Rant
    module Sys
        # Unpack the zip archive, to which the +archive+ path points.
        # Use the <tt>:in => "some/dir"</tt> option to specify a
        # output directory. It defaults to the working directory.
        def unpack_zip(archive, opts={})
            output_dir = opts[:to] || opts[:in] || "."
            mkpath output_dir unless test ?d, output_dir
            if Env.find_bin("unzip")
                sh "unzip", "-q", archive, "-d", output_dir
            else
                rubyzip_unpack(archive, output_dir)
            end
            nil
        end
        private
        def rubyzip_unpack(archive, output_dir)
            fu_output_message "unpacking #{archive} in #{output_dir}"
            require 'rant/archive/rubyzip' #rant-import:remove
            f = Archive::Rubyzip::ZipFile.open archive
            f.entries.each { |e|
                fn = e.name
                dir = File.dirname fn
                if dir == "."
                    dir = output_dir
                elsif output_dir != "."
                    dir = File.join(output_dir, dir)
                end
                FileUtils.mkpath dir unless test ?d, dir
                f.extract(e, File.join(output_dir, fn))
            }
            f.close
        end
    end # module Sys
end # module Rant
