#!/usr/bin/env ruby

require 'rant/rantlib'

def rac
    Rant.rac
end

include RantContext

if $0 == __FILE__
    exit Rant.run
end
