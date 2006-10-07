# Generator for running NUnit tests
class Rant::Generators::NUnitTest
  def self.rant_gen(rant, ch, args, &block)
    target = args.shift
    gen_args = args.shift

    # Verify arguments
    rant.abort_at(ch, "NUnitTest requires a task name") if !target ||
                                                            target.empty?
    rant.abort_at(ch, "NUnitTest requires dlls") if !gen_args[:dlls] || 
                                                     gen_args[:dlls].empty?

    # Define test task
    rant.task target do |t|
      gen_args[:bin] ||= "nunit-console /nologo"
      dlls = process_dlls(rant, gen_args[:dlls])

      rant.context.sys.sh "#{gen_args[:bin]} #{dlls}"
    end
  end

  def self.process_dlls(rant, dlls)
    if dlls.respond_to?(:arglist)
      dlls = dlls.arglist 
    elsif dlls.kind_of?(Array)
      dlls = dlls.collect{|x| rant.context.sys.sp(x)}.join(" ")
    else
      dlls = rant.context.sys.sp(dlls)
    end
    dlls
  end
end
