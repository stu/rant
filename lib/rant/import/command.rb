
# command.rb - File tasks with command chance recognition.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/signedfile'

module Rant
    def self.init_import_command(rac, *rest)
        rac.import "signedfile"
    end
    module Generators
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
                @new_sig = @sigs.signature_for_string(@command)
                old_sig != @new_sig
            end
            def run
                goto_task_home
                @rac.running_task(self)
                @rac.sys @command
                @md.path_set(@cmd_key, @new_sig, @name)
                @command = @new_sig = @cmd_key = nil
            end
        end # class Command
    end # module Generators
end # module Rant
