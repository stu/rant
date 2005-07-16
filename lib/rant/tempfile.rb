
# tempfile.rb
#
# Copyright (C) 2005 Stefan Lang <langstefan@gmx.at>

require 'tempfile'
if Tempfile.superclass == SimpleDelegator
    require 'rant/archive/rubyzip/tempfile_bugfixed'
    Rant::Tempfile = Rant::BugFix::Tempfile
else
    Rant::Tempfile = Tempfile
end
