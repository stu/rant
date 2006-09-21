require File.expand_path(File.dirname(__FILE__) + '/../csharp/mcs_compiler')

module Rant::CSharp
  class GmcsCompiler < McsCompiler
    def initialize bin = 'gmcs'
      super
    end
  end
end
