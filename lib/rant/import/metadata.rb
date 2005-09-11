
# metadata.rb - Management of meta-information for Rant targets.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    
    def self.init_import_metadata(rac, *rest)
        mi = MetaData::Interface.new(rac)
        rac.var._set("__metadata__", mi)
        rac.at_return(&mi.method(:save))
        rac.var._init("__autoclean_common__", []) << MetaData::META_FN
    end
    
    module MetaData

        META_FN = ".rant.meta"

        class Interface

            def initialize(rac)
                @rac = rac
                # the keys in this hash are project directory names,
                # the corresponding values are again hashes and their
                # keys are target names
                @store = {}
                # just a set
                @modified_dirs = {}
                # just a set
                @read_dirs = {}
            end

            # Fetch the meta value associated with the given key for
            # target in dir. Note that the value will probably end in
            # a newline. Very important is, that the +dir+ (third
            # argument, relative to the projects root directory) has
            # to be the current working directory! An example:
            #   project root directory: /home/foo/myproject
            #   dir:                    bar
            #   => Dir.pwd has to be:   /home/foo/myproject/bar
            #
            # Returns nil only if the value doesn't exist.
            def fetch(key, target, dir=@rac.current_subdir, meta_dir=nil)
                # first check if a value for the given key, target and
                # dir already exists
                dstore = @store[dir]
                if dstore
                    tstore = dstore[target]
                    if tstore
                        val = tstore[key]
                        return val if val
                    end
                end
                # check if the meta file in dir was already read
                unless @read_dirs.include? dir
                    read_meta_file_in_dir(dir, meta_dir)
                end
                tstore = @store[dir][target]
                tstore[key] if tstore
            end

            # Set the key-value pair for the given target in dir. Note
            # that if value.class is not String, the value will be
            # replaced with a newline! key should also be a string and
            # mustn't contain a newline.
            #
            # Returns nil.
            def set(key, value, target, dir=@rac.current_subdir)
                value = "\n" unless value.class == String
                @modified_dirs[dir] ||= true
                dstore = @store[dir]
                unless dstore
                    @store[dir] = {target => {key => value}}
                    return
                end
                tstore = dstore[target]
                if tstore
                    tstore[key] = value
                else
                    dstore[target] = {key => value}
                end
                nil
            end

            def path_fetch(key, target_path)
                tdir, fn = File.split target_path
                sdir = @rac.current_subdir
                if tdir == '.'
                    fetch(key, fn, sdir)
                else
                    dir = sdir.empty? ? tdir : "#{sdir}/#{tdir}"
                    fetch(key, fn, dir, tdir)
                end
            end

            def path_set(key, value, target_path)
                tdir, fn = File.split target_path
                sdir = @rac.current_subdir
                if tdir == '.'
                    dir = sdir
                else
                    dir = sdir.empty? ? tdir : "#{sdir}/#{tdir}"
                end
                #STDERR.puts "#{key}:#{value}:#{fn}:#{dir}"
                set(key, value, fn, dir)
            end

            # Assumes to be called from the projects root directory.
            def save
                @modified_dirs.each_key { |dir|
                    write_dstore(@store[dir], dir)
                }
                nil
            end

            private
            # assumes that dir is already the current working
            # directory if meta_dir is nil
            def read_meta_file_in_dir(dir, meta_dir)
                #puts "in dir: #{dir}, pwd: #{Dir.pwd}"
                @read_dirs[dir] = true
                #fn = dir.empty? ? META_FN : File.join(dir, META_FN)
                fn = meta_dir ? File.join(meta_dir, META_FN) : META_FN
                dstore = @store[dir]
                @store[dir] = dstore = {} unless dstore
                return unless File.exist? fn
                open fn do |f|
                    # first line should only contain "Rant", later
                    # Rant versions can add version and other
                    # information
                    invalid_format(fn) unless f.readline == "Rant\n"
                    until f.eof?
                        target_name = f.readline.chomp!
                        dstore[target_name] = read_target_data(f)
                    end
                end
            rescue
                invalid_format(fn)
            end

            def read_target_data(file)
                h = {}
                num_of_entries = file.readline.to_i
                num_of_entries.times { |i|
                    key = file.readline.chomp!
                    value = ""
                    file.readline.to_i.times { |j|
                        value << file.readline
                    }
                    value.chomp!
                    h[key] = value
                }
                h
            end

            # assumes to be called from the projects root directory
            def write_dstore(dstore, dir)
                fn = dir.empty? ? META_FN : File.join(dir, META_FN)
                target = sigs = key = value = lines = nil
                open fn, "w" do |f|
                    f.puts "Rant"
                    dstore.each { |target, sigs|
                        f.puts target
                        f.puts sigs.size
                        sigs.each { |key, value|
                            f.puts key
                            lines = value.split(/\n/)
                            f.puts lines.size
                            f.puts lines
                        }
                    }
                end
            end

            def invalid_format(fn)
                raise Rant::Error, "The file `#{fn}' is used by " +
                    "Rant to store meta information, it is in an\n" +
                    "invalid state. Check that it doesn't contain\n" +
                    "important data, remove it and retry."
            end

        end

    end # module MetaData
end # module Rant
