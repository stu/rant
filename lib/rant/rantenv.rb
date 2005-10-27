
# rantenv.rb - Environment interface.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rbconfig'

module Rant end

# This module interfaces with the environment to provide
# information/conversion methods in a portable manner.
module Rant::Env
    OS		= ::Config::CONFIG['target']
    RUBY	= ::Config::CONFIG['ruby_install_name']
    RUBY_BINDIR	= ::Config::CONFIG['bindir']
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
        path = on_windows? ? ENV["Path"] : ENV["PATH"]
        return [] unless path
        if on_windows?
            path.split(";")
        else
            path.split(":")
        end
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
end    # module Rant::Env

module Rant::Console
    RANT_PREFIX		= "rant: "
    ERROR_PREFIX	= "[ERROR] "
    WARN_PREFIX		= "[WARNING] "
    def msg_prefix
	if defined? @msg_prefix and @msg_prefix
	    @msg_prefix
	else
	    RANT_PREFIX
	end
    end
    def msg(*text)
        pre = msg_prefix
        $stderr.puts "#{pre}#{text.join("\n" + ' ' * pre.length)}"
    end
    def vmsg(importance, *text)
        msg(*text) if verbose >= importance
    end
    def err_msg(*text)
        pre = msg_prefix + ERROR_PREFIX
        $stderr.puts "#{pre}#{text.join("\n" + ' ' * pre.length)}"
    end
    def warn_msg(*text)
        pre = msg_prefix + WARN_PREFIX
        $stderr.puts "#{pre}#{text.join("\n" + ' ' * pre.length)}"
    end
    def ask_yes_no text
        $stderr.print msg_prefix + text + " [y|n] "
        case $stdin.readline
        when /y|yes/i: true
        when /n|no/i: false
        else
            $stderr.puts(' ' * msg_prefix.length +
                "Please answer with `yes' or `no'")
            ask_yes_no text
        end
    end
    def prompt text
        $stderr.print msg_prefix + text
        input = $stdin.readline
	input ? input.chomp : input
    end
    def option_listing opts
	rs = ""
	opts.each { |lopt, *opt_a|
	    if opt_a.size == 2
		# no short option
		mode, desc = opt_a
	    else
		sopt, mode, desc = opt_a
	    end
	    next unless desc	# "private" option
	    optstr = ""
	    arg = nil
	    if mode != GetoptLong::NO_ARGUMENT
		if desc =~ /(\b[A-Z_]{2,}\b)/
		    arg = $1
		end
	    end
	    if lopt
		optstr << lopt
		if arg
		    optstr << " " << arg
		end
		optstr = optstr.ljust(30)
	    end
	    if sopt
		optstr << "   " unless optstr.empty?
		optstr << sopt
		if arg
		    optstr << " " << arg
		end
	    end
	    rs << "  #{optstr}\n"
	    rs << "      #{desc.split("\n").join("\n      ")}\n"
	}
	rs
    end

    extend self
end
