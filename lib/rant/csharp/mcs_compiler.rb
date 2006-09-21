require File.expand_path(File.dirname(__FILE__) + '/../csharp/base_compiler_adapter')

module Rant::CSharp
  class McsCompiler < BaseCompilerAdapter
    def initialize bin = 'mcs'
      super
    end
    
    def argument_prefix
      "-"
    end
  end
end
