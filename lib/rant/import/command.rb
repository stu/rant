
# command.rb - File tasks with command change recognition.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/metautils'
#require 'rant/import/metadata' #rant-import:uncomment
#require 'rant/import/signature/md5' #rant-import:uncomment

module Rant
    def self.init_import_command(rant, *rest)
        rant.import "metadata" unless rant.var._get("__metadata__")
        rant.import "signature/md5" unless rant.var._get("__signature__")
    end
    module Node
        def interp_vars(str)
            str.gsub(/\$\((\w+|<|>)\)/) { |_|
                var = $1
                case var
                when "name", ">"
                    Rant::Sys.sp(self.name)
                when "prerequisites", "<"
                    self.prerequisites.arglist
                when "source"
                    Rant::Sys.sp(self.source)
                else
                    cx = rac.cx
                    cx.var._get(var) or (
                        if cx.instance_eval("defined? @#{var}")
                            cx.instance_variable_get "@#{var}"
                        else
                            rac.warn_msg(rac.pos_text(
                                rantfile.path, line_number),
                                "Command: undefined variable `#{var}'")
                            ""
                        end
                    )
                end
            }
        end
    end
    class CommandManager
        def initialize(cmd_str, cmd_block)
            @cmd_str = cmd_str
            @cmd_block = cmd_block
            @command = nil
        end
        def update?(node)
            res_command(node)
            @command_changed
        end
        def has_post_action?
            true
        end
        def post_run(node)
            @command.split(/\n/).each { |cmd| node.rac.sys cmd }
            if @command_changed
                node.goto_task_home
                @md.path_set(@cmd_key, @new_sig, node.name)
            end
            @command_changed = @cmd_key = @new_sig = @md = nil
        end
        private
        def res_command(node)
            return if @command
            @command =
                if @cmd_block
                    (@cmd_block.arity == 0 ?
                        @cmd_block.call :
                        @cmd_block[node]).to_str
                else
                    node.interp_vars(@cmd_str.to_str.dup)
                end
            var = node.rac.var
            @md = var._get "__metadata__"
            sigs = var._get "__signature__"
            @cmd_key = "command_sig_#{sigs.name}"
            old_sig = @md.path_fetch(@cmd_key, node.name)
            sig_str = @command.gsub(/( |\t)+/, ' ')
            @new_sig = sigs.signature_for_string(sig_str)
            @command_changed = old_sig != @new_sig
        end
    end # class CommandManager
    module Generators
        class Command
            def self.rant_gen(rant, ch, args, &block)
                name, pre, cmd = args
                rant.prepare_task({name => pre}, nil, ch) { |n,pre,_|
                    t = rant.node_factory.new_file(rant, n, pre, nil)
                    t.receiver = CommandManager.new(cmd, block)
                    t
                }
            end
        end # class Command
    end # module Generators
end # module Rant
