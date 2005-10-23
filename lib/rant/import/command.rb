
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
    module Generators
        class Command
            extend MetaUtils
            include Node

            def self.rant_gen(rant, ch, args, &block)
                name, pre, cmd = args
                rant.prepare_task({name => pre}, nil, ch) { |n,pre,_|
                    t = rant.node_factory.new_file(rant, n, pre, nil)
                    self.new(t, cmd, block)
                }
            end

            redirect_reader :@w_node,
                :name, :rac, :reference_name, :to_s, :to_rant_target,
                :full_name, :goto_task_home, :file_target?, :done?,
                :needed?, :run?, :prerequisites
            redirect_accessor :@w_node,
                :description, :rantfile, :line_number, :project_subdir

            redirect_message :@w_node, :each_target
            
            def initialize(wrapped_node, cmd_str, cmd_block)
                @w_node = wrapped_node
                @cmd_str = cmd_str
                @cmd_block = cmd_block
                @command = nil
            end
            def has_actions?
                @cmd_str || @cmd_block
            end
            def invoke(opt = INVOKE_OPT)
                ud = @w_node.invoke(opt)
                goto_task_home
                res_command
                run if ud
                if @command_changed
                    (ud = true; run) unless ud
                    @md.path_set(@cmd_key, @new_sig, name)
                end
                ud
            end
            def run
                goto_task_home
                res_command
                rac.running_task(self)
                @command.split(/\n/).each { |cmd| rac.sys cmd }
            end
            def respond_to?(msg)
                super || @w_node.respond_to?(msg)
            end
            def method_missing(meth, *args, &blk)
                if @w_node.respond_to? meth
                    @w_node.__send__(meth, *args, &blk)
                else
                    super
                end
            end
            private
            def res_command
                return if @command
                @command =
                    if @cmd_block
                        (@cmd_block.arity == 0 ?
                            @cmd_block.call :
                            @cmd_block[self]).to_str
                    else
                        interp_vars(@cmd_str.to_str.dup)
                    end
                @md = rac.var._get "__metadata__"
                sigs = rac.var._get "__signature__"
                @cmd_key = "command_sig_#{sigs.name}"
                old_sig = @md.path_fetch(@cmd_key, name)
                sig_str = @command.gsub(/( |\t)+/, ' ')
                @new_sig = sigs.signature_for_string(sig_str)
                @command_changed = old_sig != @new_sig
            end
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
        end # class Command
=begin
        class Command < SignedFile
            def initialize(rac, name, prerequisites, &block)
                super
                @cmd_block = @block
                raise "command block required" unless @cmd_block
                @block = nil
            end
            def extra_needed?
                goto_task_home
                @cmd_key = "command_sig_#{@sigs.name}"
                old_sig = @md.path_fetch(@cmd_key, @name)
                @command = @cmd_block[self].to_str
                sig_str = @command.gsub(/( |\t)+/, ' ')
                @new_sig = @sigs.signature_for_string(sig_str)
                old_sig != @new_sig
            end
            def run
                goto_task_home
                @rac.running_task(self)
                @command.split(/\n/).each { |line|
                    @rac.sys line unless line =~ /^\s*$/
                }
                @md.path_set(@cmd_key, @new_sig, @name)
                @command = @new_sig = @cmd_key = nil
            end
        end # class Command
=end
    end # module Generators
end # module Rant
