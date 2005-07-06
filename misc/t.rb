
=begin
Run this with `rant -f t.rb', it should print the following 3 lines:
Task
Rant::Task
a
=end
require 'rubygems'
#require 'rake'
require 'mt'

gen Task, "a" do |t|
    t.needed { true }
    t.act { puts t.name }
end

p ::Task
p Task
