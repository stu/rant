
# Run this script with `rant -f' to get a list of methodnames which
# allow an Rantfile to communicate with Rant.

desc "Print all methods which allow to communicate with rant."
task :rant_methods do
    ml = methods
    om = Object.instance_methods
    fu = FileUtils.instance_methods

    ml.each { |m| puts m unless om.include?(m) || fu.include?(m) }
end
