
# coregen.rb - Generators available in all Rantfiles.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    module Generators
        class Task
	    def self.rant_gen(rac, ch, args, &block)
		unless args.size == 1
		    rac.abort("Task takes only one argument " +
			"which has to be like one given to the " +
			"`task' function")
		end
		rac.prepare_task(args.first, nil, ch) { |name,pre,blk|
		    rac.node_factory.new_custom(rac, name, pre, block)
		}
	    end
        end
        class Directory
	    # Generate a task for making a directory path.
	    # Prerequisites can be given, which will be added as
	    # prerequistes for the _last_ directory.
	    #
	    # A special feature is used if you provide a block: The
	    # block will be called after complete directory creation.
	    # After the block execution, the modification time of the
	    # directory will be updated.
	    def self.rant_gen(rac, ch, args, &block)
		case args.size
		when 1
		    name, pre = rac.normalize_task_arg(args.first, ch)
		    self.task(rac, ch, name, pre, &block)
		when 2
		    basedir = args.shift
		    if basedir.respond_to? :to_str
			basedir = basedir.to_str
		    else
			rac.abort_at(ch,
			    "Directory: basedir argument has to be a string.")
		    end
		    name, pre = rac.normalize_task_arg(args.first, ch)
		    self.task(rac, ch, name, pre, basedir, &block)
		else
		    rac.abort_at(ch, "Directory takes one argument, " +
			"which should be like one given to the `task' command.")
		end
	    end

	    # Returns the task which creates the last directory
	    # element (and has all other necessary directories as
	    # prerequisites).
	    def self.task(rac, ch, name, prerequisites=[], basedir=nil, &block)
		dirs = ::Rant::Sys.split_all(name)
		if dirs.empty?
		    rac.abort_at(ch,
			"Not a valid directory name: `#{name}'")
		end
		path = basedir
		last_task = nil
		task_block = nil
		desc_for_last = rac.pop_desc
		dirs.each { |dir|
                    pre = [path]
                    pre.compact!
		    if dir.equal?(dirs.last)
			rac.cx.desc desc_for_last

                        # add prerequisites to pre
                        # if prerequisites is a FileList: there is
                        # only one save (no later removal) way to add
                        # an entry: with <<
                        dp = prerequisites.dup
                        pre.each { |elem| dp << elem }
                        pre = dp

			task_block = block
		    end
		    path = path.nil? ? dir : File.join(path, dir)
		    last_task = rac.prepare_task({:__caller__ => ch,
			    path => pre}, task_block) { |name,pre,blk|
			rac.node_factory.new_dir(rac, name, pre, blk)
		    }
		}
		last_task
	    end
        end # class Directory
        class SourceNode
            def self.rant_gen(rac, ch, args)
                unless args.size == 1
                    rac.abort_at(ch, "SourceNode takes one argument.")
                end
                if block_given?
                    rac.abort_at(ch, "SourceNode doesn't take a block.")
                end
                rac.prepare_task(args.first, nil, ch) { |name, pre, blk|
                    rac.node_factory.new_source(rac, name, pre, blk)
                }
            end
        end
	class Rule
	    # Generate a rule by installing an at_resolve hook for
	    # +rac+.
	    def self.rant_gen(rac, ch, args, &block)
		unless args.size == 1
		    rac.abort_at(ch, "Rule takes only one argument.")
		end
                rac.abort_at(ch, "Rule: block required.") unless block
		arg = args.first
		target = nil
		src_arg = nil
		if Symbol === arg
		    target = ".#{arg}"
		elsif arg.respond_to? :to_str
		    target = arg.to_str
		elsif Regexp === arg
		    target = arg
		elsif Hash === arg && arg.size == 1
		    arg.each_pair { |target, src_arg| }
		    src_arg = src_arg.to_str if src_arg.respond_to? :to_str
		    target = target.to_str if target.respond_to? :to_str
		    src_arg = ".#{src_arg}" if Symbol === src_arg
		    target = ".#{target}" if Symbol === target
		else
		    rac.abort_at(ch, "Rule argument " +
			"has to be a hash with one key-value pair.")
		end
		esc_target = nil
		target_rx = case target
                    when String
                        esc_target = Regexp.escape(target)
                        /#{esc_target}$/
                    when Regexp
                        target
                    else
		    rac.abort_at(ch, "rule target has " +
			"to be a string or regular expression")
		end
		src_proc = case src_arg
                    when String, Array
                        unless String === target
                            rac.abort(ch, "rule target has to be " +
                                  "a string if source is a string")
                        end
                        if src_arg.kind_of? String
                            lambda { |name|
                                name.sub(/#{esc_target}$/, src_arg)
                            }
                        else
                            lambda { |name|
                                src_arg.collect { |s_src|
                                    s_src = ".#{s_src}" if Symbol === s_src
                                    name.sub(/#{esc_target}$/, s_src)
                                }
                            }
                        end
                    when Proc: src_arg
                    when nil: lambda { |name| [] }
                    else
                        rac.abort_at(ch, "rule source has to be a " +
                            "String, Array or Proc")
                    end
                rac.resolve_hooks <<
                    (block.arity == 2 ? Hook : FileHook).new(
                           rac, ch, target_rx, src_proc, block)
		nil
	    end
            class Hook
                attr_accessor :target_rx
                def initialize(rant, ch, target_rx, src_proc, block)
                    @rant = rant
                    @ch = ch
                    @target_rx = target_rx
                    @src_proc = src_proc
                    @block = block
                end
                def call(target, rel_project_dir)
		    if @target_rx =~ target
                        have_src = true
                        src = @src_proc[target]
                        if src.respond_to? :to_ary
                            src.each { |f|
                                if @rant.resolve(f).empty? && !test(?e, f)
                                    have_src = false
                                    break
                                end
                            }
                        else
                            if @rant.resolve(src).empty? && !test(?e, src)
                                have_src = false
                            end
                        end
                        if have_src
                            create_nodes(rel_project_dir, target, src)
                        end
                    end
                end
                alias [] call
                private
                def create_nodes(rel_project_dir, target, deps)
                    case nodes = @block[target, deps]
                    when Array: nodes
                    when Node: [nodes]
                    else
                        @rant.abort_at(@ch, "Block has to " +
                            "return Node or array of Nodes.")
                    end.each { |node|
                        node.project_subdir = @rant.current_subdir
                    }
                end
            end
            class FileHook < Hook
                private
                def create_nodes(rel_project_dir, target, deps)
                    t = @rant.file(:__caller__ => @ch,
                            target => deps, &@block)
                    t.project_subdir = @rant.current_subdir
                    [t]
                end
            end
	end # class Rule
	class Action
	    def self.rant_gen(rac, ch, args, &block)
                case args.size
                when 0:
                    unless (rac[:tasks] || rac[:stop_after_load])
                        yield
                    end
                when 1:
                    rx = args.first
                    unless rx.kind_of? Regexp
                        rac.abort_at(ch, "Action: argument has " +
                            "to be a regular expression.")
                    end
                    rac.resolve_hooks << self.new(rac, block, rx)
                    nil
                else
                    rac.abort_at(ch, "Action: too many arguments.")
                end
	    end
            def initialize(rant, block, rx)
                @rant = rant
                @subdir = @rant.current_subdir
                @block = block
                @rx = rx
            end
            def call(target, rel_project_dir)
                if target =~ @rx
                    @rant.resolve_hooks.delete(self)
                    @rant.goto_project_dir @subdir
                    @block.call
                    @rant.resolve(target, rel_project_dir)
                end
            end
            alias [] call
	end
    end	# module Generators
end # module Rant
