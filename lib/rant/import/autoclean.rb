
# autoclean.rb - "AutoClean" generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantlib'
require 'rant/import/clean'

class Rant::Generators::AutoClean
    def self.rant_gen(rac, ch, args, &block)
	# validate args
	if args.size > 1
	    rac.abort_at(ch,
		"AutoClean doesn't take more than one argument.")
	end
	tname = args.first || "autoclean"

	# we generate a normal clean task too, so that the user can
	# add files to clean via a var
	::Rant::Generators::Clean.rant_gen(rac, ch, [tname])

	# create task
	rac.task :__caller__ => ch, tname => [] do |t|
            add_common_dirs = {}
	    rac.tasks.each { |name, node|
		if Array === node
                    f = node.first
                    if f.file_target?
                        add_common_dirs[File.dirname(f.full_name)] = true
                    end
		    node.each { |subw|
			subw.each_target { |entry| clean rac, entry }
		    }
		else
                    if node.file_target?
                        add_common_dirs[File.dirname(node.full_name)] = true
                    end
		    node.each_target { |entry| clean rac, entry }
		end
	    }
	    target_rx = nil
	    rac.resolve_hooks.each { |hook|
		if hook.respond_to? :each_target
		    hook.each_target { |entry|
                        add_common_dirs[File.expand_path(File.dirname(entry))] = true
                        clean rac, entry
		    }
		elsif hook.respond_to? :target_rx
		    next(rx) unless (t_rx = hook.target_rx)
		    target_rx = target_rx.nil? ? t_rx :
			Regexp.union(target_rx, t_rx)
		end
	    }
            t.goto_task_home
	    if target_rx
		rac.vmsg 1, "searching for rule products"
		rac.sys["**/*"].each { |entry|
		    if entry =~ target_rx
                        add_common_dirs[File.dirname(entry)] = true
                        clean rac, entry
		    end
		}
	    end
            common = rac.var._get("__autoclean_common__")
            if common
                rac.rantfiles.each{ |rf|
                    sd = rf.project_subdir
                    common.each { |fn|
                        path = sd.empty? ? fn : File.join(sd, fn)
                        clean rac, path
                    }
                }
                #STDERR.puts add_common_dirs.inspect
                add_common_dirs.each { |dir, _|
                    common.each { |fn|
                        clean rac, File.join(dir, fn)
                    }
                }
            end
	end
    end
    def self.clean(rac, entry)
        if test ?f, entry
            rac.sys.rm_f entry
        elsif test ?e, entry
            rac.sys.rm_rf entry
        end
    end
end
