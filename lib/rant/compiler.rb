
# compiler.rb - Abstraction of a native code generating compiler.
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

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

        def initialize
        end

        # name of the compiler, e.g. "gcc", "g++", "bcc", etc.
        def cc
            "gcc"
        end

    end # class Compiler
end # module Rant
