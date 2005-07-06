
# package.rb - Rant packaging support.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/archive'

# The classes in this module act as generators which create archives.
# The difference to the Archive::* generators is, that the Package
# generators move all archive entries into a toplevel directory.
module Rant::Generators::Package
    class Tgz < Rant::Generators::Archive::Tgz
	def define_tar_task
	    define_task_for_dir do |t|
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		@rac.cx.sys %W(tar zcf #{fn} #@dist_dirname)
		Dir.chdir old_pwd
	    end
	end
	def define_minitar_task
	    define_task_for_dir do
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		begin
		    @rac.cx.sys.minitar_tgz fn, @dist_dirname
		rescue LoadError
		    @rac.abort_at @ch,
			"minitar not available. " +
			"Try to install with `gem install archive-tar-minitar'."
		ensure
		    Dir.chdir old_pwd
		end
	    end
	end
    end # class Tgz

    class Zip < Rant::Generators::Archive::Zip
	def define_zip_task
	    define_task_for_dir do
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		# zip options:
		#   y: store symlinks instead of referenced files
		#   r: recurse into directories
		#   q: quiet operation
		@rac.cx.sys %W(zip -yqr #{fn} #@dist_dirname)
		Dir.chdir old_pwd
	    end
	end
	def define_rubyzip_task
	    define_task_for_dir do
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
		begin
		    @rac.cx.sys.rubyzip fn,
			@dist_dirname, :recurse => true
		rescue LoadError
		    @rac.abort_at @ch,
			"rubyzip not available. " +
			"Try to install with `gem install rubyzip'."
		ensure
		    Dir.chdir old_pwd
		end
	    end
	end
    end # class Zip
end # module Rant::Generators::Package
