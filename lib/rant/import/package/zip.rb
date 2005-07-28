
# zip.rb - Package::Zip generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/archive/zip'

module Rant::Generators::Package
    class Zip < Rant::Generators::Archive::Zip
	def define_zip_task
	    define_task_for_dir do
		fn = @dist_dirname + (@extension ? @extension : "")
		old_pwd = Dir.pwd
		Dir.chdir @dist_root
                # zip adds to existing archive
                @rac.cx.sys.rm_f fn if test ?e, fn
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
		begin
                    Dir.chdir @dist_root
                    rubyzip fn, @dist_dirname, :recurse => true
		ensure
		    Dir.chdir old_pwd
		end
	    end
	end
    end # class Zip
end # module Rant::Generators::Package
