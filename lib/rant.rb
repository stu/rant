#!/usr/bin/env ruby

require 'rant/rantlib'

include Rant
include ::Rant::FileUtils

if $0 == __FILE__
    exit Rant.run
end
