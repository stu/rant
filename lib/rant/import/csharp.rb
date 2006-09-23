require File.expand_path(File.dirname(__FILE__) + 
  '/../csharp/compiler_adapter_factory')

# Generator for compiling c sharp sources
class Rant::Generators::CSharp
  def self.rant_gen(rant, ch, args, &block)   
    target = args.shift
    cs_args = args.shift

    # Verify arguments
    rant.abort_at(ch, "CSharp requires a target") if !target || target.empty?
    rant.abort_at(ch, "CSharp requires sources") if !cs_args[:sources] || 
                                                     cs_args[:sources].empty?

    # Massage argument hash
    dependencies = []
    dependencies += cs_args[:sources]
    dependencies += cs_args[:resources] if cs_args[:resources]
    dependencies += cs_args[:libs] if cs_args[:libs]

    # Create a file target to the output file,
    # depend on all source files, resources,
    # and libs
    rant.file target => dependencies do |t|
      cmd = get_compiler(rant.context, cs_args).cmd(target, cs_args)

      rant.context.sys.sh cmd
    end
  end

  def self.compiler_adapter_factory
    @@compiler_adapter_factory ||= Rant::CSharp::CompilerAdapterFactory.new
  end
    
  def self.get_compiler(context, cs_args)
    if cs_args[:compiler]    
      if cs_args[:compiler].respond_to?(:new)
        compiler = cs_args[:compiler].new
      else
        compiler = cs_args[:compiler]
      end
      cs_args.delete(:compiler)
    else
      compiler = compiler_adapter_factory.compiler(context)
    end
    compiler
  end
end
