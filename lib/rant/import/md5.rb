
# md5.rb - Use md5 checksums to recognize source changes.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

#require 'rant/import/signature/md5' #rant-import:uncomment
#require 'rant/import/metadata' #rant-import:uncomment
#require 'rant/import/nodes/signed' #rant-import:uncomment

module Rant
    def self.init_import_md5(rac, *rest)
        rac.import "signature/md5"
        rac.import "metadata"
        rac.import "nodes/signed"
    end
end
