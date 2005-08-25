
file "r_f1" do |t|
    sys.touch t.name
end

file "r_f2" => "r_f1" do |t|
    sys.touch t.name
end

file "r_f3" => ["r_f2", :r_f4] do |t|
    sys.touch t.name
end

file "r_f4" => "r_f2" do |t|
    sys.touch t.name
end

task :clean do
    sys.rm_f Dir["r_f*"]
end
