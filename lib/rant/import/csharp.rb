require File.expand_path(File.dirname(__FILE__) + '/../csharp/compiler_adapter_factory')

# Generator for compiling c sharp sources
class Rant::Generators::CSharp
  def self.compiler_adapter_factory
    @@compiler_adapter_factory ||= Rant::CSharp::CompilerAdapterFactory.new
  end
  
  def self.rant_gen(rant, ch, args, &block)   
    target = args.shift
    cs_args = args.shift

    # Massage argument hash
    dependencies = cs_args[:sources]
    dependencies += cs_args[:resources] if cs_args[:resources]
    dependencies += cs_args[:libs] if cs_args[:libs]

    # Create a file target to the output file,
    # depend on all source files, resources,
    # and libs
    rant.file target => dependencies do |t|
      if cs_args[:compiler]    
        if cs_args[:compiler].respond_to?(:new)
          compiler = cs_args[:compiler].new
        else
          compiler = cs_args[:compiler]
        end
        cs_args.delete(:compiler)
      else
        compiler = compiler_adapter_factory.compiler(rant.context)
      end
      
      
      cmd = compiler.cmd(target, cs_args)

      rant.context.sys.sh cmd
    end
  end
end

# Create a file task for compiling resources
class Rant::Generators::Resgen
  def self.rant_gen(rant, ch, args, &block)   
    gen_args = args.shift
    gen_args[:build_dir] ||= '.'
    
    regex = Regexp.new("#{Regexp.escape(gen_args[:build_dir] + '/' + gen_args[:namespace])}\.(.+?)\.resources")
    
    src = lambda { |target| 
      [regex.match(target)[1].gsub(/\./, "/") + ".resx"] 
    }
    
    rant.context.gen ::Rant::Generators::Rule, regex => src do |t|
      rant.context.sys.sh "resgen /useSourcePath /compile #{t.source},#{t.name}"  
    end
  end
end
