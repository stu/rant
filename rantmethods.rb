
# Run this script with `rant -f' to get a list of methodnames which
# allow an Rantfile to communicate with Rant.

desc "Print all methods which allow to communicate with rant."
task :rant_methods do
    ml = methods
    om = Object.instance_methods
    fu = FileUtils.instance_methods

    ml = ml.select { |m| not om.include?(m) }.sort
    puts ml
    puts "*** total: #{ml.size} methods ***"
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
