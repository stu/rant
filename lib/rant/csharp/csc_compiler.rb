require File.expand_path(File.dirname(__FILE__) + '/../csharp/base_compiler_adapter')

module Rant::CSharp
  class CscCompiler < BaseCompilerAdapter
    def initialize bin = 'csc /nologo'
      super
      @switch_map = { :resources => "res",
                      :libs      => "r"}
    end
    
    def argument_prefix
      "/"
    end
  end
end