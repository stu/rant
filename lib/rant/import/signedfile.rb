
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
                    self.new(rac, name, pre, &blk)
                }
            end

            attr_accessor :receiver

            def initialize(rac, name, prerequisites, &block)
                super()
                @rac = rac
                @name = name
                @pre = prerequisites or
                    raise ArgumentError, "prerequisites required"
                @block = block
                @run = false
                @success = nil
                @receiver = nil
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
                @block or @receiver && @receiver.has_post_action?
            end
            def file_target?
                true
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
            def invoke(opt = INVOKE_OPT)
                return circular_dep if @run
                @run = true
                begin
                    return if done?
                    goto_task_home
                    @cur_checksums = []
                    @sigs = @rac.var._get("__signature__")
                    @md = @rac.var._get("__metadata__")
                    key = "prerequisites_sig_#{@sigs.name}"
                    target_key = "target_sig_#{@sigs.name}"
                    up = signed_process_prerequisites(opt)
                    up ||= opt[:force]
                    up = true if @receiver && @receiver.update?(self)
                    @cur_checksums.sort!
                    check_str = @cur_checksums.join
                    @cur_checksums = nil
                    old_check_str = @md.path_fetch(key, @name)
                    old_target_str = @md.path_fetch(target_key, @name)
                    # check explicitely for plain file, thus allow the
                    # target of a SignedFile to be a directory ;)
                    if test(?f, @name)
                        target_str = @sigs.signature_for_file(@name)
                    else
                        target_str = ""
                        up ||= !File.exist?(@name)
                    end
                    check_str_changed = old_check_str != check_str
                    target_changed = old_target_str != target_str
                    up ||= check_str_changed || target_changed
                    return up if opt[:needed?]
                    return false unless up
                    # run action and save checksums
                    run
                    goto_task_home
                    @receiver.post_run(self) if @receiver
                    target_str = test(?f, @name) ?
                        @sigs.signature_for_file(@name) : ""
                    target_changed = target_str != old_target_str
                    if target_changed
                        @md.path_set(target_key, target_str, @name)
                    end
                    if check_str_changed
                        @md.path_set(key, check_str, @name)
                    end
                    @success = true
                    return target_changed
                rescue TaskFail => e
                    raise
                rescue Exception => e
                    self.fail(nil, e)
                ensure
                    @md = @sigs = nil
                    @run = false
                end
            end
            def each_target
                goto_task_home
                yield @name
            end
            def timestamp(opt = INVOKE_OPT)
                File.exist?(@name) ? File.mtime(@name) : T0
            end
            def signature
                goto_task_home
                sigs = @rac.var._get("__signature__")
                md = @rac.var._get("__metadata__")
                key = "target_sig_#{sigs.name}"
                md.path_fetch(key, @name)
            end
            private
            # returns true if update required
            def signed_process_prerequisites(opt)
                up = false
                # set with already handled prerequisites, don't
                # handle on prerequisite multiple times
                handled = {@name => true}
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
            def handle_node(node, dep_str, opt)
                up = node.invoke(opt) if node.file_target?
                if node.respond_to? :signature
                    @cur_checksums << node.signature
                elsif test(?f, dep_str)
                    # calculate checksum for plain file
                    handle_file(dep_str)
                elsif File.exist?(dep_str)
                    @cur_checksums << @sigs.signature_for_string(dep_str)
                elsif !node.file_target?
                    self.fail "can't handle prerequisite `#{dep_str}'"
                end
                goto_task_home
                up
            end
            def handle_file(path)
                @cur_checksums << @sigs.signature_for_file(path)
            end
            def handle_dir(path)
                @cur_checksums << @sigs.signature_for_string(path)
            end
        end # class SignedFile

        class AutoSubSignedFile < SignedFile
            include AutoInvokeDirNode
        end

        class SignedDirectory < SignedFile
            def respond_to?(meth)
                if meth == :signature
                    @block
                else
                    super
                end
            end
            def signature
                goto_task_home
                sigs = @rac.var._get("__signature__")
                md = @rac.var._get("__metadata__")
                key = "prerequisites_sig_#{sigs.name}"
                md.path_fetch(key, @name)
            end
            private
            def run
                @rac.running_task(self)
                @rac.cx.sys.mkdir @name unless test ?d, @name
                if @block
                    @block.arity == 0 ? @block.call : @block[self]
                    goto_task_home
                    # for compatibility with mtime based tasks
                    @rac.cx.sys.touch @name
                end
            end
        end # class SignedDirectory
    end # module Generators
end # module Rant
