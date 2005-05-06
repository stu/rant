#!/usr/bin/env ruby

require 'rant/rantlib'

module RantContext
    # Needed for irb, which defines its own +source+ method.
    def source_rf(*args, &block)
	rac.source(*args, &block)
    end
end
module Rant
    class FileList
	def inspect
	    # what's the right encoding for object_id ?
	    s = "#<#{self.class}:0x#{"%x" % object_id} "
	    s << "#{@actions.size} actions, #{@files.size} files"
	    if @ignore_rx
		is = @ignore_rx.inspect.gsub(/\n|\t/, ' ')
		s << ", ignore#{is.squeeze ' '}"
	    end
	    if @glob_flags != 0
		s << ", flags:#@glob_flags"
	    end
	    s << ">"
	end
    end
    module Worker
	def inspect
	    s = "#<#{self.class}:0x#{"%x" % object_id} "
	    s << "task_id:#{full_name}, action:#{inspect_action}"
	    s << ", deps:#{inspect_deps}"
	    s << ">"
	end
	private
	def inspect_action
	    (defined? @block) ? @block.inspect : "nil"
	end
	def inspect_deps
	    if respond_to? :deps
		dl = deps
		s = dl.size.to_s
		dls = dl.join(",")
		dls[12..dls.length] = "..." if dls.length > 12
		s << "[#{dls}]"
	    else
		"0"
	    end
	end
    end
    class RantApp
	def inspect
	    s = "#<#{self.class}:0x#{"%x" % object_id} "
	    if current_subdir && !current_subdir.empty?
		s << "subdir:#{current_subdir}, "
	    end
	    s << "tasks:#{tasks.size}"
	    s << ">"
	end
    end
end

def rac
    Rant.rac
end

include RantContext

if $0 == __FILE__
    exit Rant.run
end
