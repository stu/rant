
# program.rb - Compiling C programs.

require 'rant/rantlib'
require 'rant/metautils'

module Rant

    module Generators::C end

    class Generators::C::CompileBase
        extend MetaUtils

        def self.rant_gen(rac, ch, args, &block)
            prog = self.new
            target_name = args.shift
            unless String === target_name
                rac.abort_at(ch,
                    "#{self}: filename as first argument required")
            end
            if String === args.first
                prog.name = target_name
                prog.sources = [args.shift]
            elsif FileList === args.first
                prog.name = target_name
                prog.sources = args.shift
            elsif args.first.respond_to? :to_ary
                prog.name = target_name
                prog.sources = args.shift.to_ary
            else
                # assuming first argument is a source file name, e.g.
                # hello.c
                prog.name = args.first.sub(/.[^.]$/, '')
                prog.sources = [args.shift]
            end
            # process flags
            while Symbol === args.first
                flag = args.shift
                n_flag = flag.to_s.sub(/^no_/, '')
                unless prog.respond_to? n_flag && prog.respond_to? "no_#{flag}"
                    rac.abort_at(ch,
                        "#{self}: No such flag -- #{flag}")
                end
                prog.send flag
            end
            unless args.first.nil?
                opts = args.shift
                unless args.empty? && opts.respond_to? :to_hash
                    rac.abort_at(ch,
                        "#{self}: Option hash expected after sources/flags.")
                end
                opts.to_hash.each { |k, v|
                    setter = "#{k}="
                    unless prog.respond_to? setter
                        rac.abort_at(ch,
                            "#{self}: No such option -- #{k}")
                    end
                    prog.send setter, v
                }
            end
        end

        rant_flag :optimize

    end # class Generators::C::Program

end # module Rant
