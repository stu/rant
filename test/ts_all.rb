
# assumes to be run in the test/ directory of the Rant distribution

$:.unshift(File.expand_path("../lib"))
Dir["**/test_*.rb"].each { |t| require t }
