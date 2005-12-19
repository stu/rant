
# init.rb - Define constants and methods required by all Rant code.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rbconfig'

unless Process::Status.method_defined?(:success?) # new in 1.8.2
    class Process::Status
        def success?; exitstatus == 0; end
    end
end
unless Regexp.respond_to? :union # new in 1.8.1
    def Regexp.union(*patterns)
        # let's hope it comes close to ruby-1.8.1 and upwards...
        return /(?!)/ if patterns.empty?
        Regexp.new(patterns.join("|"))
    end
end
if RUBY_VERSION < "1.8.2"
    class Array
        undef_method :flatten, :flatten!
        def flatten
            cp = self.dup
            cp.flatten!
            cp
        end
        def flatten!
            res = []
            flattened = false
            self.each { |e|
                if e.respond_to? :to_ary
                    res.concat(e.to_ary)
                    flattened = true
                else
                    res << e
                end
            }
            if flattened
                replace(res)
                flatten!
                self
            end
        end
    end
end

class String
    def _rant_sub_ext(ext, new_ext = nil)
        if new_ext
            self.sub(/#{Regexp.escape ext}$/, new_ext)
        else
            self.sub(/(\.[^.]*$)|$/, ".#{ext}")
        end
    end
end

module Rant
    VERSION = '0.5.5'

    @__rant_no_value__ = Object.new.freeze
    def self.__rant_no_value__
	@__rant_no_value__
    end

    module Env
        OS = ::Config::CONFIG['target']
        RUBY = ::Config::CONFIG['ruby_install_name']
        RUBY_BINDIR = ::Config::CONFIG['bindir']
        RUBY_EXE = File.join(RUBY_BINDIR, RUBY + ::Config::CONFIG["EXEEXT"])

        @@zip_bin = false
        @@tar_bin = false

        if OS =~ /mswin/i
            def on_windows?; true; end
        else
            def on_windows?; false; end
        end

        def have_zip?
            if @@zip_bin == false
                @@zip_bin = find_bin "zip"
            end
            !@@zip_bin.nil?
        end
        def have_tar?
            if @@tar_bin == false
                @@tar_bin = find_bin "tar"
            end
            !@@tar_bin.nil?
        end
        # Get an array with all pathes in the PATH
        # environment variable.
        def pathes
            # Windows doesn't care about case in environment variables,
            # but the ENV hash does!
            path = ENV[on_windows? ? "Path" : "PATH"]
            return [] unless path
            path.split(on_windows? ? ";" : ":")
        end
        # Searches for bin_name on path and returns
        # an absolute path if successfull or nil
        # if an executable called bin_name couldn't be found.
        def find_bin bin_name
            if on_windows?
                bin_name_exe = nil
                if bin_name !~ /\.[^\.]{1,3}$/i
                    bin_name_exe = bin_name + ".exe"
                end
                pathes.each { |dir|
                    file = File.join(dir, bin_name)
                    return file if test(?f, file)
                    if bin_name_exe
                        file = File.join(dir, bin_name_exe)
                        return file if test(?f, file)
                    end
                }
            else
                pathes.each { |dir|
                    file = File.join(dir, bin_name)
                    return file if test(?x, file)
                }
            end
            nil
        end
        # Add quotes to a path and replace File::Separators if necessary.
        def shell_path path
            # TODO: check for more characters when deciding wheter to use
            # quotes.
            if on_windows?
                path = path.tr("/", "\\")
                if path.include? ' '
                    '"' + path + '"'
                else
                    path
                end
            else
                if path.include? ' '
                    "'" + path + "'"
                else
                    path
                end
            end
        end
        extend self
    end # module Env

    module Sys
	# Returns a string that can be used as a valid path argument
	# on the shell respecting portability issues.
	def sp(arg)
            if arg.respond_to? :to_ary
                arg.to_ary.map{ |e| sp e }.join(' ')
            else
                _escaped_path arg
            end
	end
        # Escape special shell characters (currently only spaces).
        # Flattens arrays and returns always a single string.
        def escape(arg)
            if arg.respond_to? :to_ary
                arg.to_ary.map{ |e| escape e }.join(' ')
            else
                _escaped arg
            end
        end
        if Env.on_windows?
            def _escaped_path(path)
		_escaped(path.to_s.tr("/", "\\"))
            end
            def _escaped(arg)
		sarg = arg.to_s
		return sarg unless sarg.include?(" ")
		sarg << "\\" if sarg[-1].chr == "\\"
                "\"#{sarg}\""
            end
            def regular_filename(fn)
                fn.to_str.tr("\\", "/").gsub(%r{/{2,}}, "/")
            end
        else
            def _escaped_path(path)
                path.to_s.gsub(/(?=\s)/, "\\")
            end
            alias _escaped _escaped_path
            def regular_filename(fn)
                fn.to_str.gsub(%r{/{2,}}, "/")
            end
        end
        private :_escaped_path
        private :_escaped
	# Split a path in all elements.
	def split_all(path)
            names = regular_filename(path).split(%r{/})
            names[0] = "/" if names[0] && names[0].empty?
            names
	end
        extend self
    end # module Sys
end # module Rant
