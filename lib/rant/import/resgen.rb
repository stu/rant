# Create a file task for compiling resources
class Rant::Generators::Resgen
  def self.rant_gen(rant, ch, args, &block)   
    gen_args = args.shift
    gen_args[:build_dir] ||= ''
    gen_args[:build_dir] += '/' if !gen_args[:build_dir].empty?
    gen_args[:namespace] ||= ''
    gen_args[:namespace] += '.' if !gen_args[:namespace].empty?
    prefix = Regexp.escape(gen_args[:build_dir] + gen_args[:namespace])
    regex = Regexp.new("#{prefix}(.+?)\\.resources")
    
    src = lambda { |target| 
      [regex.match(target)[1].gsub(/\./, "/") + ".resx"] 
    }
    
    rant.context.gen Rant::Generators::Rule, regex => src do |t|
      rant.context.sys.sh "resgen /useSourcePath /compile " + 
                          rant.context.sys.sp("#{t.source},#{t.name}")
    end
  end
end
