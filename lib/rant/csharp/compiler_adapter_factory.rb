require File.expand_path(File.dirname(__FILE__) + '/../csharp/csc_compiler')
require File.expand_path(File.dirname(__FILE__) + '/../csharp/mcs_compiler')
require File.expand_path(File.dirname(__FILE__) + '/../csharp/gmcs_compiler')

module Rant::CSharp
  class CompilerAdapterFactory
    attr_accessor :context
    attr_accessor :compiler_map

    def initialize context
      @context = context
      @compiler = nil
      
      # Default compiler mappings
      @compiler_map ||= {
        "csc" => CscCompiler,
        "mcs" => McsCompiler,
        "gmcs" => GmcsCompiler
      }
    end
    
    def compiler
      if !@compiler
        compiler_map.each_key do |key|
          if context.env.find_bin(key)
            @compiler = compiler_map[key].new(context)
            break
          end
        end
        
        if !@compiler
          raise Exception.new("Could not find C# compiler in path (csc, mcs, gmcs). " +
                              "Please amend your path or explicitly define one with the :compiler option")
        end
      end
      
      @compiler
    end
  end
end
