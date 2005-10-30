
# command.rb - File tasks with command change recognition.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

#require 'rant/import/metadata' #rant-import:uncomment
#require 'rant/import/signature/md5' #rant-import:uncomment

module Rant
    def self.init_import_command(rant, *rest)
        rant.import "metadata" unless rant.var._get("__metadata__")
        rant.import "signature/md5" unless rant.var._get("__signature__")
    end
    module Generators
        class Command
            def self.rant_gen(rant, ch, args, &block)
                if args.size == 1 && block
                    return \
                    rant.prepare_task(args.first, nil, ch) { |n,pre,_|
                        t = rant.node_factory.new_file(rant, n, pre, nil)
                        t.receiver = CommandManager.new(nil, block)
                        t
                    }
                elsif args.size < 2
                    rant.abort_at(ch, "Command: At least two " +
                        "arguments required: task name and command.")
                elsif args.size > 3
                    rant.abort_at(ch, "Command: Too many arguments.")
                end
                # determine task name
                name = args.shift
                if name.respond_to? :to_str
                    name = name.to_str
                else
                    rant.abort_at(ch, "Command: task name (string) " +
                        "as first argument required")
                end
                if args.size == 1 && args.first.respond_to?(:to_hash)
                    parse_keyword_syntax(rant, ch,
                        name, block, args[0].to_hash)
                else
                    parse_plain_syntax(rant, ch,
                        name, block, args[0], args[1])
                end
            end
            def self.parse_plain_syntax(rant, ch, name, block, pre, cmd)
                # determine prerequisites
                pre ||= []
                # determine command
                (cmd = pre; pre = []) unless cmd
                if cmd.respond_to? :to_str
                    cmd = cmd.to_str
                else
                    rant.abort_at(ch, "Command: command argument has " +
                        "to be a string.")
                end
                rant.prepare_task({name => pre}, nil, ch) { |n,pre,_|
                    t = rant.node_factory.new_file(rant, n, pre, nil)
                    t.receiver = CommandManager.new(cmd, block)
                    t
                }
            end
            def self.parse_keyword_syntax(rant, ch, name, block, hash)
                # TODO
                rant.abort_at(ch, "Command: syntax error")
            end
        end # class Command
    end # module Generators
    module Node
        def interp_vars!(str)
            str.gsub!(/\$\((\w+)\)/) { |_|
                val = val_for_interp_var($1)
                unless val.respond_to?(:to_ary)
                    val = val.to_s
                    interp_vars!(val) 
                end
                Sys.sp(val)
            }
            str.gsub!(/\$\{(\w+)\}/) { |_|
                val = val_for_interp_var($1)
                unless val.respond_to?(:to_ary)
                    val = val.to_s
                    interp_vars!(val) 
                end
                Sys.escape(val)
            }
            str.gsub!(/\$\[(\w+)\]/) { |_|
                val = val_for_interp_var($1)
                if val.respond_to?(:to_ary)
                    val.to_ary.join(' ')
                else
                    val = val.to_s
                    interp_vars!(val)
                end
                val
            }
            str
        end
        def interp_symbolic_vars!(str)
            str.gsub!(/\$\((-|<|>)\)/) { |_|
                Sys.sp(val_for_interp_sym($1))
            }
            str.gsub!(/\$\{(-|<|>)\}/) { |_|
                Sys.escape(val_for_interp_sym($1))
            }
            str.gsub!(/\$\[(-|<|>)\]/) { |_|
                val = val_for_interp_sym($1)
                val.respond_to?(:to_ary) ? val.to_ary.join(' ') : val.to_s
            }
            str
        end
        private
        def val_for_interp_var(var)
            case var
            when "name": self.name
            when "prerequisites": self.prerequisites
            when "source": self.source
            else
                cx = rac.cx
                val = cx.var._get(var) || (
                    if cx.instance_eval("defined? @#{var}")
                        cx.instance_variable_get "@#{var}"
                    else
                        rac.warn_msg(rac.pos_text(
                            rantfile.path, line_number),
                            "Command: undefined variable `#{var}'")
                        ""
                    end
                )
                if val.respond_to?(:call) && val.respond_to?(:arity)
                    val.arity == 0 ? val.call : val.call(self)
                elsif val.respond_to?(:to_hash)
                    rac.warn_msg(
                        "`#{var}' -- Avoid interpolation of hashes.\n" +
                        "Behaviour is undecided.")
                    ""
                    #val.to_hash[full_name]
                else
                    val
                end
            end
        end
        def val_for_interp_sym(sym)
            case sym
            when ">": name
            when "<": prerequisites
            when "-": source
            end
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
        def has_pre_action?
            true
        end
        def pre_run(node)
	    dir = File.dirname(node.name)
            unless dir == "." || dir == "/"
                node.rac.build dir, :type => :file 
            end
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
                    cmd = (@cmd_block.arity == 0 ?
                        @cmd_block.call :
                        @cmd_block[node])
                    if cmd.respond_to? :to_str
                        cmd.to_str.dup
                    else
                        node.rac.abort_at(node.ch,
                            "Command: block has to return command string.")
                    end
                else
                    node.interp_vars!(@cmd_str.to_str.dup)
                end
            var = node.rac.var
            @md = var._get "__metadata__"
            sigs = var._get "__signature__"
            @cmd_key = "command_sig_#{sigs.name}"
            old_sig = @md.path_fetch(@cmd_key, node.name)
            sig_str = @command.gsub(/( |\t)+/, ' ')
            sig_str.gsub!(/\[#.*?#\]/, '')
            @command.gsub!(/\[#(.*?)#\]/) { |_| $1 }
            node.interp_symbolic_vars!(@command)
            @new_sig = sigs.signature_for_string(sig_str)
            @command_changed = old_sig != @new_sig
        end
    end # class CommandManager
end # module Rant
