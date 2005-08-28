
# tgz.rb - +sys+ methods for tgz archiving.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

#require 'rant/archive/minitar' #rant-import:uncomment

module Rant
    module Sys
        # Unpack the gzipped tar archive, to which the +archive+ path
        # points. Use the <tt>:in => "some/dir"</tt> option to specify
        # a output directory. It defaults to the working directory.
        def unpack_tgz(archive, opts={})
            output_dir = opts[:to] || opts[:in] || "."
            mkpath output_dir unless test ?d, output_dir
            if Env.have_tar?
                sh "tar", "-xzf", archive, "-C", output_dir
            else
                minitar_unpack(archive, output_dir)
            end
            nil
        end
        private
        def minitar_tgz(fn, files, opts)
            require 'zlib'
            require 'rant/archive/minitar' #rant-import:remove
            fu_output_message "minitar #{fn}"
            files = files.to_ary if files.respond_to? :to_ary
            tgz = Zlib::GzipWriter.new(File.open(fn, 'wb'))
            # pack closes tgz
            Rant::Archive::Minitar.pack(files, tgz, opts[:recurse])
            nil
        end
        def minitar_unpack(archive, output_dir)
            fu_output_message "unpacking #{archive} in #{output_dir}"
            require 'zlib'
            require 'rant/archive/minitar' #rant-import:remove
            tgz = Zlib::GzipReader.new(File.open(archive, 'rb'))
            # unpack closes tgz
            Archive::Minitar.unpack(tgz, output_dir)
        end
    end # module Sys
end # module Rant
