
# signed.rb - "Signed" node types for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/signedfile'

module Rant
    def self.init_import_nodes__signed(rac, *rest)
        rac.import "signature/md5" unless rac.var._get("__signature__")
        rac.import "metadata" unless rac.var._get("__metadata__")
        rac.node_factory = SignedNodeFactory.new
    end
    class SignedNodeFactory < DefaultNodeFactory
        def new_file(rac, name, pre, blk)
            Generators::SignedFile.new(rac, name, pre, &blk)
        end
        def new_dir(rac, name, pre, blk)
            Generators::SignedDirectory.new(rac, name, pre, &blk)
        end
        def new_auto_subfile(rac, name, pre, blk)
            Generators::AutoSubSignedFile.new(rac, name, pre, &blk)
        end
    end
end # module Rant
