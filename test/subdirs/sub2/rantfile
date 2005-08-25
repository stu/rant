
subdirs "sub"

file "t" do |t|
    sys.touch t.name
end

file "subdep.t" => "sub/rootdep.t" do |t|
    sys.touch t.name
end

task :clean do
    sys.rm_f Dir["*t"]
end
