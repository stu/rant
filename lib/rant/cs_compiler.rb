#!/usr/bin/ruby

require 'rant/env'

# An object extending this module acts as an
# interface to a C# Compiler.
module Rant::CsCompiler

    LIB_SYSTEM_XML	= "System.Xml.dll"
    LIB_SYSTEM_DRAWING	= "System.Drawing.dll"
    LIB_SYSTEM_FORMS	= "System.Windows.Forms.dll"

    # Descriptive name for compiler.
    attr_reader :name
    # Compiler path, or cmd on PATH
    attr_accessor :cc
    # Debug flag.
    attr_accessor :debug
    # Target filename.
    attr_accessor :out
    # Libraries to link angainst (usually dlls).
    attr_reader :libs
    # Other args, could be options.
    # Initialized to an empty array.
    attr_accessor :misc_args
    # Sourcefiles.
    attr_accessor :sources
    # Resources to embedd in assembly.
    attr_accessor :resources
    # Library include pathes.
    attr_reader :lib_include_pathes
    # Library link pathes.
    attr_reader :lib_link_pathes
    # Entry point for executable.
    attr_accessor :entry
    # Optimize, defaults to true
    attr_accessor :optimize
    # Enable compiler warnings, defaults to true
    attr_accessor :warnings

    private
    def init
        @name = "C# Compiler"
        @libs = []
        @sources = []
        @misc_args = []
        @resources = []
        @debug = false
        @out = "a.out"
        @lib_include_pathes = []
        @lib_link_pathes = []
        @entry = nil
        @optimize = true
        @warnings = true
    end

    public
    # Generate compilation command for executable.
    def cmd_exe
        # This generates the compilation command
        # for cscc.
        cc_cmd = cc.dup
        cc_cmd << " -e#{entry}" if entry
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    # Generate command for DLL.
    def cmd_shared
        cc_cmd = cc.dup
        cc_cmd << " -shared"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    # Generate command for object file.
    def cmd_object
        cc_cmd = cc.dup
        cc_cmd << " -c"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    # Add C# sources in dir.
    def cs_source_dir dir
        @sources ||= []
        # TODO: better unique check
        sd = File.join(dir, "*.cs")
        @sources << sd unless @sources.include? sd
    end

    # Using System.Xml?
    def use_xml?
        @libs.include? LIB_SYSTEM_XML
    end

    # Set this to true to ensure System.Xml
    # will be linked against.
    def use_xml=(bval)
        if bval && !use_xml?
            @libs << LIB_SYSTEM_XML
        else
            @libs.delete LIB_SYSTEM_XML
        end
    end

    # Using WinForms?
    def use_forms?
        @libs.include? LIB_SYSTEM_DRAWING and
            @libs.include? LIB_SYSTEM_FORMS
    end

    def use_forms=(bval)
        if bval
            unless @libs.include? LIB_SYSTEM_DRAWING
                @libs << LIB_SYSTEM_DRAWING 
            end
            unless @libs.include? LIB_SYSTEM_FORMS
                @libs << LIB_SYSTEM_FORMS
            end
        elsif use_forms?
            @libs.delete LIB_SYSTEM_FORMS
            @libs.delete LIB_SYSTEM_DRAWING
        end
    end

    def to_s
        cc + "\n" + "Interface: " + name
    end

    # Search for a C# compiler in PATH and some
    # usual locations.
    def look_for_cs_compiler
        csc_bin = nil
        if Env.on_windows?
            csc_bin = "csc" if Env.find_bin "csc"
            unless csc_bin
                csc_bin = look_for_csc
            end
        end
        csc_bin = "cscc" if !csc_bin && Env.find_bin("cscc") 
        csc_bin
    end
    
    # Searches for csc in some usual directories.
    # Ment to be used on windows only!
    def look_for_csc
        # Is there a way to get a list of all available
        # drives?
        ("C".."Z").each { |drive|
            ["WINDOWS", "WINNT"].each { |win_dir|
                frame_dir = drive + ':\\' + win_dir +
                    'Microsoft.NET\Framework'
                next unless File.exist? frame_dir
                csc_pathes = []
                Dir.entries(frame_dir).each { |e|
                    if test ?d,e
                        csc_path = File.join(frame_dir, e, "csc.exe")
                        if test ?e,csc_path
                            csc_pathes << csc_path
                        end
                    end
                }
                next if csc_pathes.empty?
                return csc_pathes.sort.first
            }
        }
        nil
    rescue
        nil
    end
    module_function :look_for_cs_compiler, :look_for_csc

    private
    def cc_cmd_args
        # TODO: Argument quoting (OS dependent!).
        cc_args = ""
        cc_args << " -g -D DEBUG" if debug
        cc_args << " -o #{out}" if out
        # cscc --help states that -Wall enables all warnings,
        # but when -Wall is supplied it shouts "unrecongized option -Wall"
        #cc_args << " -Wall" if warnings
        cc_args << " -O2" if optimize
        lib_include_pathes.each { |p|
            cc_args << " -I #{p}"
        }
        lib_link_pathes.each { |p|
            cc_args << " -L #{p}"
        }
        libs.each { |p|
            cc_args << " -l #{p}"
        }
        cc_args << " " << misc_args.join(' ') if misc_args
        resources.each { |p|
            cc_args << " -fresources=#{p}"
        }
        cc_args << " " << sources.join(" ") if sources
        cc_args
    end

end    # module Rant::CsCompiler

# cscc, DotGNU C# Compiler
class Rant::Cscc
    include Rant::CsCompiler

    def initialize *args
        init
        @name = "cscc, DotGNU C# Compiler"
        @cc = "cscc"
    end

    def use_forms?
        misc_args and misc_args.include? "-winforms"
    end

    def use_forms=(bval)
        @misc_args ||= []
        if bval
            misc_args << "-winforms" unless misc_args.include? "-winforms"
        else
            misc_args.delete "-winforms"
        end
    end
end    # class DotNET::Cscc

# csc, MS .NET C# Compiler
# Assuming use on Windows.
class Rant::Csc
    include Rant::CsCompiler

    def initialize *args
        init
        @name = "csc, MS .NET C# Compiler"
        @cc = "csc"
    end

    # Generate compilation command for executable.
    def cmd_exe
        # This generates the compilation command
        # for csc.
        cc_cmd = cc.dup
        # Use target:winexe only if not debugging,
        # because this will suppress a background console window.
        cc_cmd << " /target:winexe" unless debug
        cc_cmd << " /main:#{entry}" if entry
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    # Generate command for DLL.
    def cmd_shared
        cc_cmd = cc.dup
        cc_cmd << " /target:library"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    # Generate command for object file.
    def cmd_object
        cc_cmd = cc.dup
        cc_cmd << " /target:module"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    private
    def cc_cmd_args
        # TODO: Argument quoting (OS dependent!).
        cc_args = ""
        cc_args << " /debug /d:DEBUG" if debug
        cc_args << " /out:#{out}" if out
	cc_args << " /optimize" if optimize
        # TODO: cc_args << " -Wall" if warnings
        lib_include_pathes.each { |p|
            #TODO:    cc_args << " -I #{p}"
        }
        lib_link_pathes.each { |p|
            #TODO:    cc_args << " -L #{p}"
        }
        libs.each { |p|
            cc_args << " /r:#{p}"
        }
        resources.each { |p|
            cc_args << " /res:#{p}"
        }
        cc_args << " " << sources.join(" ") if sources
        cc_args
    end

end    # class Rant::Csc
