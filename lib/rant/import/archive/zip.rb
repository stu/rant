
# zip.rb - Archive::Zip generator for Rant.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/import/archive'
#require 'rant/archive/rubyzip' #rant-import:uncomment

module Rant::Generators::Archive
    # Use this class as a generator to create zip archives.
    class Zip < Base
	def initialize(*args)
	    super
	    @extension = ".zip"
	end
	# Ensure to set #rac first.
	# Creates a file task wich invokes zip to create a zip
	# archive. Returns the created task.
	def define_task
	    if ::Rant::Env.have_zip?
		define_zip_task
	    else
		define_rubyzip_task
	    end
	end
	def define_zip_task
	    define_cmd_task { |path, t|
                # Add -y option to store symlinks instead of
                # referenced files.
		cmd = "zip -@q #{t.name}"
		@rac.cmd_msg cmd
		IO.popen cmd, "w" do |z|
		    z.print IO.read(path)
		end
		raise Rant::CommandError.new(cmd, $?) unless $?.success?
	    }
	end
	def define_rubyzip_task
	    define_cmd_task do |path, t|
                rubyzip t.name, @res_files
	    end
	end
        def rubyzip fn, files, opts = {:recurse => false}
            require 'rant/archive/rubyzip'
            # rubyzip creates only a new file if fn doesn't exist
            @rac.sys.rm_f fn if test ?e, fn
            @rac.cmd_msg "rubyzip #{fn}"
            Rant::Archive::Rubyzip::ZipFile.open fn,
                Rant::Archive::Rubyzip::ZipFile::CREATE do |z|
                if opts[:recurse]
                    require 'find'
                    files.each { |f|
                        if test ?d, f
                            Find.find(f) { |f2| z.add f2, f2 }
                        else
                            z.add f, f
                        end
                    }
                else
                    files.each { |f|
                        z.add f, f
                    }
                end
            end
            nil
        end

    end # class Zip
end # module Rant::Generators::Archive
