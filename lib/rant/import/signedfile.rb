
# signedfile.rb - File tasks with checksum change recognition.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    def self.init_import_signedfile(rac, *rest)
        rac.import "signature/md5" unless rac.var._get("__signature__")
        rac.import "metadata" unless rac.var._get("__metadata__")
    end
    module Generators
        class SignedFile
            include Node

            def self.rant_gen(rac, ch, args, &block)
                unless args.size == 1
                    rac.abort_at(ch, "SignedFile: too many arguments")
                end
                rac.prepare_task(args.first, block, ch) { |name,pre,blk|
                    SignedFile.new(rac, name, pre, &blk)
                }
            end

            def initialize(rac, name, prerequisites, &block)
                super()
                @rac = rac
                @name = name
                @pre = prerequisites or
                    raise ArgumentError, "prerequisites required"
                @block = block
                @run = false
                @success = nil
                @needed_blk = nil
            end
            def prerequisites
                @pre
            end
            alias deps prerequisites
            # first prerequisite
            def source
                @pre.first.to_s
            end
            def has_actions?
                !!@block
            end
            def <<(pre)
                @pre << pre
            end
            def invoked?
                !@success.nil?
            end
            def fail?
                @success == false
            end
            def done?
                @success
            end
            def enhance(deps = nil, &blk)
                @pre.concat(deps) if deps
                if @block
                    if blk
                        first_block = @block
                        @block = lambda { |t|
                            first_block[t]
                            blk[t]
                        }
                    end
                else
                    @block = blk
                end
            end
            def needed?
                invoke(:needed? => true)
            end
            def needed(&blk)
                @needed_blk = blk
            end
            def invoke(opt = INVOKE_OPT)
                return circular_dep if @run
                @run = true
                begin
                    return if done?
                    goto_task_home
                    @cur_checksums = []
                    @sigs = @rac.var._get("__signature__")
                    key = "prerequisites_sig_#{@sigs.name}"
                    target_key = "target_sig_#{@sigs.name}"
                    up = signed_process_prerequisites(opt)
                    if @needed_blk
                        up = true if @needed_blk.call(self)
                    end
                    @cur_checksums.sort!
                    check_str = @cur_checksums.join
                    @cur_checksums = nil
                    metadata = @rac.var._get("__metadata__")
                    old_check_str = metadata.fetch(key, @name)
                    old_target_str = metadata.fetch(target_key, @name)
                    if File.exist?(@name)
                        target_str = @sigs.signature_for_file(@name)
                    else
                        target_str = nil
                        up = true
                    end
                    check_str_changed = old_check_str != check_str
                    target_changed = old_target_str != target_str
                    up ||= check_str_changed || target_changed
                    return up if opt[:needed?]
                    return false unless up
                    # run action and save checksums
                    run
                    target_str = File.exist?(@name) ?
                        @sigs.signature_for_file(@name) : "0"
                    target_changed = target_str != old_target_str
                    if target_changed
                        metadata.set(target_key, target_str, @name)
                    end
                    if check_str_changed
                        metadata.set(key, check_str, @name)
                    end
                    return target_changed
                rescue TaskFail => e
                    raise
                rescue Exception => e
                    self.fail(nil, e)
                ensure
                    @sigs = nil
                    @run = false
                end
            end
            def each_target
                goto_task_home
                yield @name
            end
            def timestamp
                File.exist?(@name) ? File.mtime(@name) : T0
            end
            private
            # returns true if update required
            def signed_process_prerequisites(opt)
                up = false
                # set with already handled prerequisites, don't
                # handle on prerequisite multiple times
                handled = {}
                my_subdir = project_subdir
                @pre.each { |dep|
                    dep_str = dep.to_rant_target
                    next if handled.include? dep_str
                    if Node === dep
                        up = true if handle_node(dep, dep_str, opt)
                    else
                        tasks = @rac.resolve(dep_str, my_subdir)
                        if tasks.empty?
                            if test(?d, dep_str)
                                handle_dir(dep_str)
                            elsif File.exist?(dep_str)
                                handle_file(dep_str)
                            else
                                rac.err_msg @rac.pos_text(rantfile.path, line_number),
                                    "in prerequisites: no such file or task: `#{dep_str}'"
                                self.fail
                            end
                        else
                            tasks.each { |t|
                                up = true if handle_node(t, dep_str, opt)
                            }
                        end
                    end
                    handled[dep_str] = true
                }
                up
            end
            def handle_node(dep, dep_str, opt)
                up = dep.invoke(opt)
                # calculate checksum for plain file
                if test(?f, dep_str)
                    @cur_checksums << @sigs.signature_for_file(dep_str)
                end
                goto_task_home
                up
            end
            def handle_file(path)
                @cur_checksums << @sigs.signature_for_file(path)
            end
            def handle_dir(path)
                @cur_checksums << @sigs.signature_for_dir(path)
            end
        end # class SignedFile
    end # module Generators
end # module Rant
