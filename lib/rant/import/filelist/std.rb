
# std.rb - Additional set of Rant::FileList instance methods.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

# What should this file be used for:
#
# Place <code>import "filelist/std"</code> in an Rantfile to get all
# functionality as defined after <code>require "rant/filelist"</code>
# (for use as library). Read doc/filelist.rdoc.

require 'rant/import/filelist/inspect'

module Rant
    class FileList
        # Remove all entries which contain a directory with the
        # given name.
        # If no argument or +nil+ given, remove all directories.
        #
        # Example:
        #       file_list.no_dir "CVS"
        # would remove the following entries from file_list:
        #       CVS/
        #       src/CVS/lib.c
        #       CVS/foo/bar/
        def no_dir(name = nil)
            @actions << [:apply_no_dir, name]
            @pending = true
            self
        end
        def apply_no_dir(name)
            entry = nil
            unless name
                @items.reject! { |entry|
                    test(?d, entry) && !@keep[entry]
                }
                return
            end
            elems = nil
            @items.reject! { |entry|
                next if @keep[entry]
                elems = Sys.split_all(entry)
                i = elems.index(name)
                if i
                    path = File.join(*elems[0..i])
                    test(?d, path)
                else
                    false
                end
            }
        end
        private :apply_no_dir
        # Get a new filelist containing only the existing files from
        # this filelist.
        def files
            select { |entry| test ?f, entry }
        end
        # Get a new filelist containing only the existing directories
        # from this filelist.
        def dirs
            select { |entry| test ?d, entry }
        end
    end # class FileList
end # module Rant
