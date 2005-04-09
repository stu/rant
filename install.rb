
# Install Rant with Rant :)
$:.unshift File.expand_path(File.join(File.dirname(__FILE__), "lib"))
require 'rant/rantlib'

exit Rant.run("install")
