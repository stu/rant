
# core.rb - Core functionality for the Rant::FileList class.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

module Rant
    def FileList(arg)
        if arg.respond_to?(:to_rant_filelist)
            arg.to_rant_filelist
        elsif arg.respond_to?(:to_ary)
            FileList.new.concat(arg.to_ary)
        elsif arg.respond_to?(:to_str)
            FileList.new(arg.to_str)
        else
            raise TypeError,
                "cannot convert #{arg.class} into Rant::FileList"
        end
    end
    module_function :FileList
    class FileList
        include Enumerable

        ESC_SEPARATOR = Regexp.escape(File::SEPARATOR)
        ESC_ALT_SEPARATOR = File::ALT_SEPARATOR ?
            Regexp.escape(File::ALT_SEPARATOR) : nil

        class << self
            def [](*patterns)
                new(*patterns)
            end
            def glob(*patterns)
                fl = new(*patterns)
                fl.ignore(".", "..")
                if block_given? then yield fl else fl end
            end
            def glob_all(*patterns)
                fl = new(*patterns)
                fl.match_dotfiles
                fl.ignore(".", "..") # use case: "*.*" as pattern
                if block_given? then yield fl else fl end
            end
        end

        def initialize(*patterns)
            @glob_flags = 0
            @files = []
            @actions = patterns.map { |pat| [:apply_include, pat] }
            @ignore_rx = nil
            @pending = !@actions.empty?
            @keep = {}
        end
        def ignore_dotfiles?
            (@glob_flags & File::FNM_DOTMATCH) != File::FNM_DOTMATCH
        end
        def ignore_dotfiles=(bool)
            if bool
                @glob_flags &= ~File::FNM_DOTMATCH
            else
                @glob_flags |= File::FNM_DOTMATCH
            end
        end
        # Has the same effect as <tt>ignore_dotfiles = false</tt>.
        #
        # Returns self.
        def match_dotfiles
            @glob_flags |= File::FNM_DOTMATCH
            self
        end
        def dup
            c = super
            c.files = @files.dup
            c.actions = @actions.dup
            c.ignore_rx = @ignore_rx.dup if @ignore_rx
            c.instance_variable_set(:@keep, @keep.dup)
            c
        end

        protected
        attr_accessor :actions, :files
        attr_accessor :pending
        attr_accessor :ignore_rx

        public
        def each(&block)
            resolve if @pending
            @files.each(&block)
        end
        def to_ary
            resolve if @pending
            @files
        end
        alias to_a to_ary
        alias entries to_ary    # entries: defined in Enumerable
        def to_rant_filelist
            self
        end
        def +(other)
            if other.respond_to? :to_rant_filelist
                c = other.to_rant_filelist.dup
                c.actions.concat(@actions)
                c.files.concat(@files)
                c.pending = !c.actions.empty?
                c
            elsif other.respond_to? :to_ary
                c = dup
                c.actions <<
                    [:apply_ary_method_1, :concat, other.to_ary.dup]
                c.pending = true
                c
            else
                raise TypeError,
                    "cannot add #{other.class} to Rant::FileList"
            end
        end
        # Use this method to append +file+ to this list. +file+ will
        # stay in this list even if it matches an exclude or ignore
        # pattern.
        #
        # Returns self.
        def <<(file)
            @actions << [:apply_ary_method_1, :push, file]
            @keep[file] = true
            @pending = true
            self
        end
        # Add +entry+ to this filelist. Position of +entry+ in this
        # list is undefined. More efficient than #<<. +entry+ will
        # stay in this list even if it matches an exclude or ignore
        # pattern.
        #
        # Returns self.
        def keep(entry)
            @keep[entry] = true
            @files << entry
            self
        end
        # Append the entries of +ary+ (an array like object) to
        # this list.
        def concat(ary)
            resolve if @pending
            if ix = ignore_rx
                @files.concat(ary.to_ary.reject { |f| f =~ ix })
            else
                # Array#concat(arg) calls arg.to_ary anyway
                @files.concat(ary)
            end
            self
        end
        # Number of entries in this filelist.
        def size
            resolve if @pending
            @files.size
        end
        alias length size
        def empty?
            resolve if @pending
            @files.empty?
        end
        def join(sep = ' ')
            resolve if @pending
            @files.join(sep)
        end
        def pop
            resolve if @pending
            @files.pop
        end
        def push(entry)
            resolve if @pending
            @files.push(entry) if entry !~ ix
            self
        end
        def shift
            resolve if @pending
            @files.shift
        end
        def unshift(entry)
            resolve if @pending
            ix = ignore_rx
            @files.unshift(entry) if entry !~ ix
            self
        end
if Object.method_defined?(:fcall) || Object.method_defined?(:funcall) # in Ruby 1.9 like __send__
        @@__send_private__ = Object.method_defined?(:fcall) ? :fcall : :funcall
        def resolve
            @pending = false
            @actions.each{ |action| self.__send__(@@__send_private__, *action) }.clear
            ix = ignore_rx
            if ix
                @files.reject! { |f| f =~ ix && !@keep[f] }
            end
        end
elsif RUBY_VERSION < "1.8.2"
        def resolve
            @pending = false
            @actions.each{ |action| self.__send__(*action) }.clear
            ix = ignore_rx
            @files.reject! { |f|
                unless @keep[f]
                    next(true) if ix && f =~ ix
                    if @glob_flags & File::FNM_DOTMATCH != File::FNM_DOTMATCH
                        if ESC_ALT_SEPARATOR
                            f =~ /(^|(#{ESC_SEPARATOR}|#{ESC_ALT_SEPARATOR})+)\..*
                                ((#{ESC_SEPARATOR}|#{ESC_ALT_SEPARATOR})+|$)/x
                        else
                            f =~ /(^|#{ESC_SEPARATOR}+)\..*
                                (#{ESC_SEPARATOR}+|$)/x
                        end
                    end
                end
            }
        end
else
        # Force evaluation of all patterns.
        def resolve
            @pending = false
            @actions.each{ |action| self.__send__(*action) }.clear
            ix = ignore_rx
            if ix
                @files.reject! { |f| f =~ ix && !@keep[f] }
            end
        end
end
        # Include entries matching one of +patterns+ in this filelist.
        def include(*patterns)
            patterns.flatten.each { |pat|
                @actions << [:apply_include, pat]
            }
            @pending = true
            self
        end
        alias glob include
        def apply_include(pattern)
            @files.concat Dir.glob(pattern, @glob_flags)
        end
        private :apply_include
        # Exclude all entries matching one of +patterns+ from this
        # filelist.
        #
        # Note: Only applies to entries previousely included.
        def exclude(*patterns)
            patterns.each { |pat|
                if Regexp === pat
                    @actions << [:apply_exclude_rx, pat]
                else
                    @actions << [:apply_exclude, pat]
                end
            }
            @pending = true
            self
        end
        def ignore(*patterns)
            patterns.each { |pat|
                add_ignore_rx(Regexp === pat ? pat : mk_all_rx(pat))
            }
            @pending = true
            self
        end
        def add_ignore_rx(rx)
            @ignore_rx =
            if @ignore_rx
                Regexp.union(@ignore_rx, rx)
            else
                rx
            end
        end
        private :add_ignore_rx
        def apply_exclude(pattern)
            @files.reject! { |elem|
                File.fnmatch?(pattern, elem, @glob_flags) && !@keep[elem]
            }
        end
        private :apply_exclude
        def apply_exclude_rx(rx)
            @files.reject! { |elem|
                elem =~ rx && !@keep[elem]
            }
        end
        private :apply_exclude_rx
        def exclude_all(*names)
            names.each { |name|
                @actions << [:apply_exclude_rx, mk_all_rx(name)]
            }
            @pending = true
            self
        end
        alias shun exclude_all
        if File::ALT_SEPARATOR
            # TODO: check for FS case sensitivity?
            def mk_all_rx(file)
                /(^|(#{ESC_SEPARATOR}|#{ESC_ALT_SEPARATOR})+)#{Regexp.escape(file)}
                    ((#{ESC_SEPARATOR}|#{ESC_ALT_SEPARATOR})+|$)/x
            end
        else
            def mk_all_rx(file)
                /(^|#{ESC_SEPARATOR}+)#{Regexp.escape(file)}
                    (#{ESC_SEPARATOR}+|$)/x
            end
        end
        private :mk_all_rx
        def select(&block)
            d = dup
            d.actions << [:apply_select, block]
            d.pending = true
            d
        end
        alias find_all select
        def apply_select blk
            @files = @files.select(&blk)
        end
        private :apply_select
        def map(&block)
            d = dup
            d.actions << [:apply_ary_method, :map!, block]
            d.pending = true
            d
        end
        alias collect map
        def sub_ext(ext, new_ext=nil)
            map { |f| f._rant_sub_ext ext, new_ext }
        end
        def ext(ext_str)
            sub_ext(ext_str)
        end
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
                @files.reject! { |entry|
                    test(?d, entry) && !@keep[entry]
                }
                return
            end
            elems = nil
            @files.reject! { |entry|
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
        # Get a string with all entries. This is very usefull
        # if you invoke a shell:
        #       files # => ["foo/bar", "with space"]
        #       sh "rdoc #{files.arglist}"
        # will result on windows:
        #       rdoc foo\bar "with space"
        # on other systems:
        #       rdoc foo/bar with\ space
        def arglist
            Rant::Sys.sp to_ary
        end
        alias to_s arglist
        # Same as #uniq! but evaluation is delayed until the next read
        # access (e.g. by calling #each). Always returns self.
        def uniq!
            @actions << [:apply_ary_method, :uniq!]
            @pending = true
            self
        end
        # Same as #sort! but evaluation is delayed until the next read
        # access (e.g. by calling #each). Always returns self.
        def sort!
            @actions << [:apply_ary_method, :sort!]
            @pending = true
            self
        end
        # Same as #map! but evaluation is delayed until the next read
        # access (e.g. by calling #each). Always returns self.
        def map!(&block)
            @actions << [:apply_ary_method, :map!, block]
            @pending = true
            self
        end
        def reject!(&block)
            @actions << [:apply_ary_method, :reject!, block]
            @pending = true
            self
        end
        private
        def apply_ary_method(meth, block=nil)
            @files.send meth, &block
        end
        def apply_ary_method_1(meth, arg1, block=nil)
            @files.send meth, arg1, &block
        end
=begin
        def apply_lazy_operation(meth, args, block)
            @files.send(meth, *args, &block)
        end
=end
    end # class FileList
end # module Rant
