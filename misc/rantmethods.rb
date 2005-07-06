
# Run this script with `rant -f' to get a list of methodnames which
# allow an Rantfile to communicate with Rant.

desc "Print all methods which allow to communicate with rant."
task :rant_methods do
    ml = methods
    om = Object.instance_methods

    ml = ml.select { |m| not om.include?(m) }.sort
    puts ml
    puts "*** total: #{ml.size} methods ***"
end

desc "Print constants introduced by Rant."
task :constants do
    puts((self.class.constants - Object.constants).sort)
end

desc "Print all attribute writers of a Gem::Specification."
task :gem_attrs do
    require 'rubygems'
    ml = []
    Gem::Specification.new do |s| ml = s.methods end
    ml = ml.select { |m| m =~ /\w=$/ }.sort
    puts ml
    puts "*** total: #{ml.size} methods ***"
end

file "bench-rant" do |t|
    c = 2000
    if var["TC"]
	c = Integer(var["TC"])
    end
    File.open(t.name, "w") { |f|
	f.puts "$tc_run = 0"
	c.times { |i|
	    f << <<-EOT
	    	task "#{i}" => "#{i+1}" do
		    $tc_run += 1
		end
	    EOT
	}
	f << <<-EOT
	    task "#{c}" do
		$tc_run += 1
	    end
	    at_exit {
		puts $tc_run.to_s + " tasks run"
	    }
	EOT
    }
end

file "bench-depsearch" do |t|
    c = 2000
    if var["TC"]
	c = Integer var["TC"]
    end
    File.open(t.name, "w") { |f|
	f.puts "$tc_run = 0"
	all = []
	c.times { |i|
	    all << i.to_s
	    f << <<-EOT
		task "#{i}" => "#{c}" do
		    print "*"
		    $tc_run += 1
		end
	    EOT
	}
	f << <<-EOT
	    task :all => %w(#{all.join(" ")})
	    task "#{c}" do
		print "+"
		$tc_run += 1
	    end
	    at_exit {
		puts
		puts $tc_run.to_s + " tasks run"
	    }
	EOT
    }
end
