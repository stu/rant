
require 'rant/env'

# An object extending this module acts as an
# interface to a C# Compiler.
class Rant::CsCompiler

    LIB_SYSTEM_XML	= "System.Xml.dll"
    LIB_SYSTEM_DRAWING	= "System.Drawing.dll"
    LIB_SYSTEM_FORMS	= "System.Windows.Forms.dll"

    class << self
	# Get the short name for the compiler referenced by this path.
	def cs_compiler_name(path)
	    case path
	    when /csc(\.exe)?$/i
		"csc"
	    when /cscc(\.exe)?$/i
		"cscc"
	    when /mcs(\.exe)?$/i
		"mcs"
	    else
		nil
	    end
	end

	# Search for a C# compiler in PATH and some
	# usual locations.
	def look_for_cs_compiler
	    # TODO: look for mcs
	    csc_bin = nil
	    if Env.on_windows?
		csc_bin = "csc" if Env.find_bin "csc"
		unless csc_bin
		    csc_bin = look_for_csc
		end
	    end
	    csc_bin = "cscc" if !csc_bin && Env.find_bin("cscc") 
	    csc_bin = "mcs" if !csc_bin && Env.find_bin("mcs")
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
		    '\Microsoft.NET\Framework'
		    next unless test(?d,frame_dir)
		    csc_pathes = []
		    Dir.entries(frame_dir).each { |e|
			if test(?d,e)
			    csc_path = File.join(frame_dir, e, "csc.exe")
			    if test(?e,csc_path)
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
    end

    # Short name for compiler, such as "csc", "cscc" or "mcs".
    attr_reader :name
    # Descriptive name for compiler.
    attr_reader :long_name
    # Compiler path, or cmd on PATH
    attr_writer :cc
    # Debug flag.
    attr_accessor :debug
    # Target filename.
    attr_accessor :out
    # Libraries to link angainst (usually dlls).
    attr_accessor :libs
    # Preprocessor defines.
    attr_reader :defines
    # Other args, could be options.
    # Initialized to an empty array.
    attr_accessor :misc_args
    # Hash with compiler specific arguments.
    attr_accessor :specific_args
    # Sourcefiles.
    attr_accessor :sources
    # Resources to embedd in assembly.
    attr_accessor :resources
    # Library link pathes.
    attr_reader :lib_link_pathes
    # Entry point for executable.
    attr_accessor :entry
    # Optimize, defaults to true
    attr_accessor :optimize
    # Enable compiler warnings, defaults to true
    attr_accessor :warnings

    def initialize(compiler_name=nil)
	self.name = (compiler_name || "cscc")
        @long_name = "C# Compiler"
	@defines = []
        @libs = []
        @sources = nil
        @misc_args = []
	@specific_args = {
	    "cscc"  => [],
	    "csc"   => [],
	    "mcs"   => [],
	}
        @resources = []
        @debug = false
        @out = "a.out"
        @lib_link_pathes = []
        @entry = nil
        @optimize = true
        @warnings = true
	@cc = nil
    end

    def cc
	@cc || @name
    end

    def name= new_name
	unless ["cscc", "csc", "mcs"].include?(new_name)
	    raise "Unsupported C# compiler `#{new_name}'"
	end
	@name = new_name
	@long_name = case @name
	when "cscc":	"DotGNU C# compiler"
	when "csc":	"MS Visual.NET C# compiler"
	when "mcs":	"Mono C# compiler"
	end
    end

    # Generate compilation command for executable.
    def cmd_exe
	send @name + "_cmd_exe"
    end

    def cscc_cmd_exe
        # This generates the compilation command
        # for cscc.
        cc_cmd = cc.dup
        cc_cmd << " -e#{entry}" if entry
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    def csc_cmd_exe
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

    def mcs_cmd_exe
	# Generate compilation command for mcs.
	cc_cmd = cc.dup
	cc_cmd << " -target:exe"
	cc_cmd << " -main:#{entry}" if entry
	cc_cmd << cc_cmd_args
	cc_cmd
    end

    # Generate command for DLL.
    def cmd_dll
	send @name + "_cmd_dll"
    end

    def cscc_cmd_dll
        cc_cmd = cc.dup
	cc_cmd << " -shared"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    def csc_cmd_dll
        cc_cmd = cc.dup
        cc_cmd << " /target:library"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    def mcs_cmd_dll
	cc_cmd = cc.dup
	cc_cmd << " -target:library"
	cc_cmd << cc_cmd_args
	cc_cmd
    end

    # Generate command for object file.
    def cmd_object
	send @name + "_cmd_object"
    end

    def cscc_cmd_object
        cc_cmd = cc.dup
        cc_cmd << " -c"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    def csc_cmd_object
        cc_cmd = cc.dup
        cc_cmd << " /target:module"
        cc_cmd << cc_cmd_args
        cc_cmd
    end

    def mcs_cmd_object
	cc_cmd = cc.dup
	cc_cmd << " -target:module"
	cc_cmd << cc_cmd_args
	cc_cmd
    end

    def to_s
        cc + "\n" + "Interface: " + name
    end

    private
    def cc_cmd_args
	send @name + "_cmd_args"
    end

    def cscc_cmd_args
        cc_args = ""
        cc_args << " -o #{out}" if out
        cc_args << " -g -DDEBUG" if debug
	defines.each { |p|
	    cc_args << " -D#{p}"
	}
        cc_args << " -Wall" if warnings
        cc_args << " -O2" if optimize
        lib_link_pathes.each { |p|
            cc_args << " -L #{p}"
        }
        libs.each { |p|
            cc_args << " -l #{p}"
        }
        cc_args << " " << misc_args.join(' ') if misc_args
	sargs = specific_args["cscc"]
	cc_args << " " << sargs.join(' ') if sargs
        resources.each { |p|
            cc_args << " -fresources=#{p}"
        }
        cc_args << " " << sources.join(" ") if sources
        cc_args
    end

    def csc_cmd_args
        cc_args = ""
        cc_args << " /out:#{out}" if out
        cc_args << " /debug /d:DEBUG" if debug
	defines.each { |p|
	    cc_args << " /d:#{p}"
	}
	cc_args << " /optimize" if optimize
        # TODO: cc_args << " -Wall" if warnings
        lib_link_pathes.each { |p|
            #TODO:    cc_args << " -L #{p}"
        }
        libs.each { |p|
            cc_args << " /r:#{p}"
        }
        cc_args << " " << misc_args.join(' ') if misc_args
	sargs = specific_args["csc"]
	cc_args << " " << sargs.join(' ') if sargs
        resources.each { |p|
            cc_args << " /res:#{p}"
        }
        cc_args << " " << sources.join(" ") if sources
        cc_args
    end

    def mcs_cmd_args
        cc_args = ""
        cc_args << " -o #{out}" if out
        cc_args << " -g -d:DEBUG" if debug
	defines.each { |p|
	    cc_args << " -d:#{p}"
	}
	cc_args << " -optimize" if optimize
	# Warning level for mcs: highest 4, default 2
        cc_args << " -warn:4" if warnings
	lib_link_pathes.each { |p|
	    cc_args << " -L #{p}"
	}
	if libs && !libs.empty?
	    cc_args << " -r:" + libs.join(',')
	end
        cc_args << " " << misc_args.join(' ') if misc_args
	sargs = specific_args["mcs"]
	cc_args << " " << sargs.join(' ') if sargs
        resources.each { |p|
            cc_args << " -resource:#{p}"
        }
        cc_args << " " << sources.join(' ') if sources
        cc_args
    end

end    # class Rant::CsCompiler
