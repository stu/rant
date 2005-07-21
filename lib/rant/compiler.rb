
# compiler.rb - Abstraction of a native code generating compiler.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'rant/rantvar'

module Rant
    class Compiler

        class << self
            @all = {}
            @factories = {}
            def [](cc)
                unless @all.include? cc
                    f = @factories[cc]
                    return nil unless f
                    @all[cc] = f.new
                end
                @all[cc]
            end
            def []=(cc, val)
                @all[cc] = val
            end
            def add_factory(cc, factory)
                @factories[cc] = factory
            end
        end

        # how to invoke the compiler, e.g. "gcc-3.4" or if it isn't in
        # Env.pathes: "/usr/local/bin/gcc", etc.
        attr_accessor :bin
        # name of the compiler, e.g. "gcc", "g++", "bcc", etc.
        attr_reader :name

        def initialize
            @name = "cc"
        end

        def cmd_program(var)

        end

        # Generic, project wide compiler flags.
        class GenericFlags
            include MetaUtils
            def initialize
                @optimize = nil
                @debug = nil
                @warn = nil
                @include_pathes = []
                @defines = []
                @cc_specific_flags = {}
            end
            rant_flag :debug
            rant_flag :warn
            def optimize(level=__rant_no_value__)
                @optimize = case level
                    when __rant_no_value__: true
                    when Integer: level
                    else
                        raise ArgumentError, "optimize: " +
                            "no argument or integer argument required"
                    end
            end
            def no_optimize
                @optimize = false
            end
            def optimize?
                @optimize
            end
            def include_path(path)
                @include_pathes << path
                self
            end
            def define(symbol, val=nil)
                @defines << [symbol, val]
                self
            end
            def [](cc)
                flags = @cc_specific_flags[cc]
                return flags if flags
                @cc_specific_flags[cc] = []
            end
            private
            # modifies str in place!
            def expand_var(str)
                str.gsub!(/\$\(#{Regexp.escape str}\)/)
            end
        end # class GenericFlags

        # Flags for one target (program, static or dynamic library)
        class TargetFlags < GenericFlags
            def initialize
                super
            end
        end

    end # class Compiler
end # module Rant
