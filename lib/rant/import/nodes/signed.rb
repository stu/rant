
# signed.rb - "Signed" node types for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/signedfile'

module Rant
    def self.init_import_nodes__signed(rac, *rest)
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
        def new_source(rac, name, pre, blk)
            SignedSourceNode.new(rac, name, pre, &blk)
        end
    end
    class SignedSourceNode < SourceNode
        def initialize(*args)
            super
            @signature = nil
        end
        # Invokes prerequisites and returns a signature of the source
        # file and all related source files.
        # Note: The signature will only be calculated once.
        def signature(opt = INVOKE_OPT)
            return circular_dep if @run
            @run = true
            begin
                return @signature if @signature
                goto_task_home
                sig_list = []
                sig = @rac.var._get("__signature__")
                if test(?f, @name)
                    @signature = sig.signature_for_file(@name)
                else
                    @rac.abort(rac.pos_text(@rantfile, @line_number),
                        "SourceNode: no such file -- #@name")
                end
                sd = project_subdir
                handled = {@name => true}
                @pre.each { |f|
                    f = f.to_rant_target
                    next if handled.include? f
                    nodes = rac.resolve f, sd
                    if nodes.empty?
                        if test(?f, f)
                            sig_list << sig.signature_for_file(f)
                        else
                            rac.abort(rac.pos_text(@rantfile, @line_number),
                                "SourceNode: no such file -- #{f}")
                        end
                    else
                        file_sig = nil
                        nodes.each { |node|
                            node.invoke(opt)
                            if node.respond_to? :signature
                                sig_list << node.signature
                                goto_task_home
                            else
                                rac.abort(rac.pos_text(@rantfile, @line_number),
                                    "SourceNode can't depend on #{node.name}")
                            end
                        }
                        sig_list << file_sig if file_sig
                    end
                    handled[f] = true
                }
                sig_list.sort!
                @signature << sig_list.join
            ensure
                @run = false
            end
        end
    end # class SignedSourceNode
end # module Rant
