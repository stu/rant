# -*- encoding: utf-8 -*-

$LOAD_PATH.unshift  File.expand_path('../lib', __FILE__)
require 'rant/version'
Gem::Specification.new('rant', Rant::VERSION) do |s|
  s.summary = "Rant is a flexible build tool written entirely in Ruby."
  s.description = <<EOF
The equivalent to a Makefile for make is the Rantfile. An
Rantfile is actually a valid Ruby script that is read in by the
rant command.
EOF

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Stefan Lang", "Xavier Shay", "Russel Winder"]
  
  s.homepage = "http://rubyforge.org/projects/rant/"
  s.licenses = ["Ruby license"]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 1.9.2"
  s.rubyforge_project = "rant"

  s.files += Dir['lib/**/*.rb']
  s.test_files += Dir["test/**/*"]
  s.executables += %w(rant rant-import)
  s.extra_rdoc_files += %w(COPYING INSTALL misc/TODO)
end
