#  Rant support for LaTeX processing
#
#  Copyright © 2006 Russel Winder
#
#  This program is free software; you can redistribute it and/or modify it under the terms of
#  the GNU General Public License as published by the Free Software Foundation; either version 2,
#  or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
#  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
#  the GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along with this program; if
#  not, write to the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
#  02111-1307 USA

#  Various bits and pieces for processing LaTeX source from a Rantfile.
#
#  Author:: Russel Winder
#  Copyright:: Copyright © 2006 Russel Winder
#  Licence:: GPL

require 'rant/rantlib'

module Rant

  #def self.init_import_latex( rac , *rest )
  #  p rac
  #end

  module LaTeX
  
    LtxExtension = '.ltx'
    TexExtension = '.tex'

    DviExtension = '.dvi'
    EpsExtension = '.eps'
    PdfExtension = '.pdf'
    PsExtension = '.ps'

    AuxExtension = '.aux'
    BblExtension = '.bbl'
    BlgExtension = '.blg'
    IdxExtension = '.idx'
    IlgExtension = '.ilg'
    IndExtension = '.ind'
    LogExtension = '.log'
    TocExtension = '.toc'
    PdfBookMarkExtension = '.out'

    CleanListExtensions = [
                           AuxExtension , DviExtension , LogExtension , TocExtension ,
                           BblExtension , BlgExtension ,
                           IdxExtension , IlgExtension , IndExtension ,
                           PdfBookMarkExtension
                          ]

    # The options to the various commands -- there must be a neater way of doing this.

    $bibtexOptions = '-min-crossrefs=999'
    $makeindexOptions = '-c'
    $dvipsOptions = '-D 1200'
    $ps2pdfOptions = '-sPAPERSIZE=a4 -dPDFSETTINGS=/printer'

    #  Run the LaTeX or pdfLaTeX command (second parameter true means pdfLaTeX otherwise LaTeX) sufficient
    #  time to ensure the resulting file (DVI or PDF depending on whether LaTeX or pdfLaTeX is being used.) 
    #  is correct.  If there are BibTeX references then run BibTeX appropriately.  If there are index files
    #  then run makeindex appropriately.

    def LaTeX.runLaTeX( root , use_pdfLaTeX = false )
      if File.exists?( root + LtxExtension ) then source = root + LtxExtension
      elsif File.exists?( root + TexExtension ) then source = root + LtxExtension
      else raise Exception.new( "Neither #{root}.ltx or #{root}.tex exist." ) end
      doLaTeX = proc { Rant::Sys.sh( ( use_pdfLaTeX ? 'pdflatex' : 'latex' ) + ' ' + source ) }
      conditionallyDoLaTeX = proc {
        rerun = File.open( root + LogExtension ) { | file | file.read.index( /(Warning:.*Rerun|Warning:.*undefined)/ ) != nil }
        if rerun then doLaTeX.call end
        rerun
      }
      doLaTeX.call
      bibTeXRun = false
      Dir.glob( root + '.*.aux' ).each { | file | Rant::Sys.sh( "bibtex #{$bibtexOptions} #{file}" ) ; bibTeXRun = true }
      if File.open( root + AuxExtension ) { | file | file.read.index( 'bibdata' ) != nil }
        Rant::Sys.sh( "bibtex #{$bibtexOptions} #{root}#{AuxExtension}" )
        bibTeXRun = true
      end
      if bibTeXRun then doLaTeX.call end
      makeindexRun = false
      Dir.glob( root + '*.idx' ).each { | file | Rant::Sys.sh( "makeindex #{$makeindexOptions} #{file}" ) ; makeindexRun = true }
      if makeindexRun then doLaTeX.call end
      doLaTeX.call
      if conditionallyDoLaTeX.call
        if ! conditionallyDoLaTeX.call
          raise Exception.new( '#### Something SERIOUSLY Wrong. ###' )
        end
      end
    end

    #  As the method name says, create a PostScript file from a DVI file.  This currently uses dvips a fact
    #  that must be known to the LaTeX source code to ensure the correct driver is used to create the DVI
    #  file.

    def LaTeX.createPsFromDvi( root )
      Rant::Sys.sh( "dvips #{$dvipsOptions} -o #{root}#{PsExtension} #{root}#{DviExtension}" )
    end

    #  As the method name says, create a PDF file from a DVI file.  This currently uses dvips and then
    #  ps2pdf a fact that must be known to the LaTeX source code to ensure the correct driver is used to
    #  create the DVI file.

    def LaTeX.createPdfFromDvi( root )
      Rant::Sys.sh( "dvips #{$dvipsOptions} -Ppdf -G0 -o #{root}#{PsExtension} #{root}#{DviExtension}" )
      Rant::Sys.sh( "ps2pdf #{ps2pdfOptions} #{root}#{PsExtension}" )
    end

  end # module LaTeX

  class Generators::LaTeX
    
    def self.rant_gen ( rant , ch , args , &block )
      if args == [] then raise ArgumentError , 'Must provide source file name as parameter.' end
      sourceFile = args.shift
      if args != [] then properties = args.shift else properties = {} end
      targetExtension = case properties[ 'generate' ]
                        when 'ps' , 'PS' , 'postscript' , 'Postscript' , 'PostScript'
                          Rant::LaTeX::PsExtension
                        else
                          Rant::LaTeX::PdfExtension
                        end
      sourceExtension = File.extname( sourceFile )
      root = sourceFile.sub( sourceExtension , '' )
      target = root + targetExtension
      dependencies = [ sourceFile ]
      if properties[ 'parts' ] then dependencies += properties[ 'parts' ] end
      rant.desc "Create #{target}."
      rant.file target => dependencies do
        case targetExtension
        when Rant::LaTeX::PdfExtension
          Rant::LaTeX.runLaTeX( root , true )
        when Rant::LaTeX::PsExtension
          Rant::LaTeX.runLaTeX( root , false )
          Rant::LaTeX.createPsFromDvi( root )
        else
          raise ArgumentError , "#{targetExtension} is not a valid extension to the LaTeX generator." 
        end
      end
      begin
        Rant::LaTeX::CleanListExtensions.each { | ext | rant.var[:clean].include root + ext }
      rescue
      end
      target
    end

  end # class Generators::LaTeX

end # module Rant
