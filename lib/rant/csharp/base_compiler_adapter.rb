# Helper method to add a to_cs_arg method to a class (yay meta!)
def add_to_cs_arg_method klass, &block
  klass.instance_eval { define_method :to_cs_arg, &block }
end

def add_to_cmd_array klass, &block
  klass.instance_eval { define_method :to_cmd_array, &block}
end

# Methods to convert types into arguments for the compiler
add_to_cs_arg_method(Object) do |key, compiler|
  compiler.string_argument(key, self.to_s)
end

add_to_cs_arg_method(TrueClass) do |key, compiler| 
  compiler.boolean_argument(key, true)
end

add_to_cs_arg_method(FalseClass) do |key, compiler|
  compiler.boolean_argument(key, false)
end

add_to_cs_arg_method(Array) do |key, compiler| 
  self.collect {|x| x.to_cs_arg(key, compiler) }
end

add_to_cmd_array(Object) do |context|
  [context.sys.sp(self.to_s)]
end

add_to_cmd_array(Array) do |context| 
  self.collect {|x| context.sys.sp(x) }
end

add_to_cmd_array(Rant::FileList) do |context| 
  [self.arglist]
end

module Rant::CSharp
  class BaseCompilerAdapter
    attr_accessor :bin
    attr_accessor :switch_map
    
    def initialize bin = ""
      @bin = bin
      @switch_map = {}
      raise Exception.new("Must specify an executable") if !@bin || 
                                                            @bin.length == 0
    end
    
    def cmd target, cs_args, context
      @context = context
      
      if !target || target.length == 0
        raise Exception.new("Target must be specified and have a length " +
                            "greater than 0")
      end
      
      # Generic argument processing
      args = []
      sources = cs_args.delete(:sources)
      cs_args[:target] ||= guess_target(target)
      
      cs_args.each_key do |key|
        args.push(cs_args[key].to_cs_arg(key, self))
      end

      src_list = sources.to_cmd_array(context)

      ([bin, outfile(target)] + args.flatten + src_list).join(' ')
    end

    # Map rant arguments to compiler arguments
    def map_arg arg
      switch_map[arg] ? switch_map[arg] : arg
    end
    
    def outfile target
      string_argument "out", target
    end
    
    def boolean_argument arg, on
      switch = map_arg(arg)
      ret = "#{self.argument_prefix}#{switch}"
      ret += on ? "" : "-"
    end
    
    def string_argument arg, value
      switch = map_arg(arg)
      # Assume all string arguments except target are
      # files
      value = @context.sys.sp(value) if arg != :target
     
      "#{self.argument_prefix}#{switch}:#{value}"
    end

    def argument_prefix
      ""
    end
    
    # Try to automatically guess the type of output file
    # based on the extension
    def guess_target outfile
      target = "library"
      
      ext = outfile.match(/\.([^\.]+)$/)
      ext = ext[1] if ext
      
      if ext
        case ext.downcase
        when "netmodule"
          target = map_target("module")
        when "exe"
          target = map_target("winexe")
        end
      end
      target
    end
    
    # Allows subclasses to override default target names
    def map_target target
      target
    end
  end
end
