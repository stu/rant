
# md5.rb - Recognize file changes by md5 checksums.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'digest/md5'

module Rant

    def self.init_import_signature__md5(rac, *rest)
        sig = Signature::MD5.new(rac)
        rac.var._set("__signature_md5__", sig)
        rac.var._init("__signature__", sig)
    end

    module Signature

        class MD5

            def initialize(rac)
                #@rac = rac
            end

            def name
                "md5"
            end

            def signature_for_file(filename)
                signature_for_string(File.read(filename))
            end

            def signature_for_dir(dirname)
                entries = Dir.entries(dirname)
                entries.sort!
                signature_for_string(entries.join << entries.size.to_s)
            end

            def signature_for_io(io)
                signature_for_string(io.read)
            end

            def signature_for_string(str)
                Digest::MD5.hexdigest(str)
            end

            private

        end # class MD5
    end # module Signature
end # module Rant
