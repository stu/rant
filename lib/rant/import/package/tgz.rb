
# tgz.rb - Package::Tgz generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/archive/tgz'

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
                begin
                    Dir.chdir @dist_root
                    minitar_tgz fn, @dist_dirname, :recurse => true
                ensure
                    Dir.chdir old_pwd
                end
            end
	end
    end # class Tgz
end # module Rant::Generators::Package
