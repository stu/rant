#!/usr/bin/ruby

require 'rbconfig'

module Rant end

class Rant::Path
    attr_reader :path
    def initialize path
	@path = path or raise ArgumentError, "path not given"
    end
    def to_s
	@path.dup
    end
    def to_str
	@path.dup
    end
    def exist?
	File.exist? @path
    end
    def file?
	test ?f, @path
    end
    def dir?
	test ?d, @path
    end
    def mtime
	File.mtime @path
    end
    def absolute_path
	File.expand_path(@path)
    end
end

# This module provides some platform indenpendant
# (let's hope) environment information.
module Rant::Env
    OS		= ::Config::CONFIG['target']
    RUBY	= ::Config::CONFIG['ruby_install_name']

    @@zip_bin = false
    @@tar_bin = false

    def on_windows?
        OS =~ /mswin/i
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
    def msg *text
        pre = msg_prefix
        text = text.join("\n" + ' ' * pre.length)
        $stderr.puts(pre + text)
    end
    def err_msg *text
        pre = msg_prefix + ERROR_PREFIX
        text = text.join("\n" + ' ' * pre.length)
        $stderr.puts(pre + text)
    end
    def warn_msg *text
        pre = msg_prefix + WARN_PREFIX
        text = text.join("\n" + ' ' * pre.length)
        $stderr.puts(pre + text)
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
    module_function :msg, :err_msg, :warn_msg, :ask_yes_no, :prompt
end

class Rant::CustomConsole
    include Rant::Console

    def initialize msg_prefix = RANT_PREFIX
	@msg_prefix = msg_prefix || ""
    end
    def msg_prefix=(str)
	@msg_prefix = str || ""
    end
end
