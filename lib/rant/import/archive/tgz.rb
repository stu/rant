
# tgz.rb - Archive::Tgz generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/archive'
#require 'rant/archive/minitar' #rant-import:uncomment

module Rant::Generators::Archive
    # Use this class as a generator to create gzip compressed tar
    # archives.
    class Tgz < Base
	def initialize(*args)
	    super
	    @extension = ".tgz"
	end
	# Ensure to set #rac first.
	# Creates a file task wich invokes tar to create a tgz
	# archive. Returns the created task.
	def define_task
	    if ::Rant::Env.have_tar?
		define_tar_task
	    else
		define_minitar_task
	    end
	end
        private
	def define_tar_task
	    define_cmd_task { |path, t|
		@rac.cx.sys "tar --no-recursion --files-from #{path} -czf #{t.name}"
	    }
	end
	def define_minitar_task
	    define_cmd_task do |path, t|
                minitar_tgz t.name, @res_files
	    end
	end
        def minitar_tgz fn, files, opts = {:recurse => false}
            require 'zlib'
            require 'rant/archive/minitar'
            @rac.cmd_msg "minitar #{fn}"
            files = files.to_ary if files.respond_to? :to_ary
            tgz = Zlib::GzipWriter.new(File.open(fn, 'wb'))
            # pack closes tgz
            Rant::Archive::Minitar.pack(files, tgz, opts[:recurse])
            nil
        end
    end # class Tgz
end # module Rant::Generators::Archive
