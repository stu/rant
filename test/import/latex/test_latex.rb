#  Test for the LaTeX generator for Rant.
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

require 'test/unit'
require 'tutil'

$testImportLatexDir ||= File.expand_path(File.dirname(__FILE__))

class TestLaTeX < Test::Unit::TestCase

  include Rant::TestUtil

  SourceFileName = 'file.ltx'
  PdfTarget = SourceFileName.sub( 'ltx' , 'pdf' )
  PsTarget = SourceFileName.sub( 'ltx' , 'ps' )
  RantfileName = 'Rantfile'
  DefaultTarget = ''
  ErrorTarget = 'flobadob'

  NoSourceRantfile = "import 'latex'\ngen LaTeX"
  MissingSourceRantfile = "import 'latex'\ngen LaTeX , 'blah.ltx'"
  NoOptionsSourceRantfile = "import 'latex'\ngen LaTeX , '#{SourceFileName}'"
  PdfOptionSourceRantfile = "import 'latex'\ngen LaTeX , '#{SourceFileName}' , { 'generate' => 'PDF' }"
  PsOptionSourceRantfile = "import 'latex'\ngen LaTeX , '#{SourceFileName}' , { 'generate' => 'PS' }"

  NoSourceErrorMessage = 'Must provide source file name as parameter.'

  def cantMakeErrorMessage( target ) ; "Don't know how to make `#{target}'" end

  def setup
    Dir.chdir( $testImportLatexDir )
  end

  def teardown
    Dir.chdir( $testImportLatexDir )
    Rant::Sys.rm_f( RantfileName )
    Rant::Sys.rm_f( Rant::LaTeX::CleanListExtensions.map { | extension | SourceFileName.sub( '.ltx' , extension ) } + [ PdfTarget , PsTarget ] )
  end

  def test_noSourceDefault
    Rant::TestUtil.write_to_file( RantfileName , NoSourceRantfile )
    out , err = assert_rant( :fail , DefaultTarget )
    assert( err.include?( NoSourceErrorMessage ) )
  end

  def test_noSourcePdfTarget
    Rant::TestUtil.write_to_file( RantfileName , NoSourceRantfile )
    out , err = assert_rant( :fail , PdfTarget )
    assert( err.include?( NoSourceErrorMessage ) )
  end

  def test_noSourcePsTarget
    Rant::TestUtil.write_to_file( RantfileName , NoSourceRantfile )
    out , err = assert_rant( :fail , PsTarget )
    assert( err.include?( NoSourceErrorMessage ) )
  end

  def test_noSourceErrorTarget
    Rant::TestUtil.write_to_file( RantfileName , NoSourceRantfile )
    out , err = assert_rant( :fail , ErrorTarget )
    assert( err.include?( NoSourceErrorMessage ) )
  end

  def test_missingSourceDefault
    Rant::TestUtil.write_to_file( RantfileName , MissingSourceRantfile )
    out , err = assert_rant( :fail , DefaultTarget )
    assert( err.include?( cantMakeErrorMessage( DefaultTarget ) ) )
  end

  def test_missingSourcePdfTarget
    Rant::TestUtil.write_to_file( RantfileName , MissingSourceRantfile )
    out , err = assert_rant( :fail , PdfTarget )
    assert( err.include?( cantMakeErrorMessage( PdfTarget ) ) )
  end

  def test_missingSourcePsTarget
    Rant::TestUtil.write_to_file( RantfileName , MissingSourceRantfile )
    out , err = assert_rant( :fail , PsTarget )
    assert( err.include?( cantMakeErrorMessage( PsTarget ) ) )
  end

  def test_missingSourceErrorTarget
    Rant::TestUtil.write_to_file( RantfileName , MissingSourceRantfile )
    out , err = assert_rant( :fail , ErrorTarget )
    assert( err.include?( cantMakeErrorMessage( ErrorTarget ) ) )
  end

  def test_noOptionsDefault
    Rant::TestUtil.write_to_file( RantfileName , NoOptionsSourceRantfile )
    out , err = assert_rant( :fail , DefaultTarget )
    assert( err.include?( cantMakeErrorMessage( DefaultTarget ) ) )
  end

  def test_noOptionsPdfTarget
    Rant::TestUtil.write_to_file( RantfileName , NoOptionsSourceRantfile )
    out , err = assert_rant( PdfTarget )
    assert( File.exists?( PdfTarget ) )
  end

  def test_noOptionsPsTarget
    Rant::TestUtil.write_to_file( RantfileName , NoOptionsSourceRantfile )
    out , err = assert_rant( :fail , PsTarget )
    assert( err.include?( "Don't know how to make `#{PsTarget}'" ) )
  end

  def test_hoOptionsErrorTarget
    Rant::TestUtil.write_to_file( RantfileName , NoOptionsSourceRantfile )
    out , err = assert_rant( :fail , ErrorTarget )
    assert( err.include?( "Don't know how to make `#{ErrorTarget}'" ) )
  end

  def test_pdfOptionDefault
    Rant::TestUtil.write_to_file( RantfileName , PdfOptionSourceRantfile )
    out , err = assert_rant( :fail , DefaultTarget )
    assert( err.include?( cantMakeErrorMessage( DefaultTarget ) ) )
  end

  def test_pdfOptionPdfTarget
    Rant::TestUtil.write_to_file( RantfileName , PdfOptionSourceRantfile )
    out , err = assert_rant( PdfTarget )
    assert( File.exists?( PdfTarget ) )
  end

  def test_pdfOptionPsTarget
    Rant::TestUtil.write_to_file( RantfileName , PdfOptionSourceRantfile )
    out , err = assert_rant( :fail , PsTarget )
    assert( err.include?( "Don't know how to make `#{PsTarget}'" ) )
  end

  def test_pdfOptionErrorTarget
    Rant::TestUtil.write_to_file( RantfileName , PdfOptionSourceRantfile )
    out , err = assert_rant( :fail , ErrorTarget )
    assert( err.include?( "Don't know how to make `#{ErrorTarget}'" ) )
  end

  def test_psOptionDefault
    Rant::TestUtil.write_to_file( RantfileName , PsOptionSourceRantfile )
    out , err = assert_rant( :fail , DefaultTarget )
    assert( err.include?( cantMakeErrorMessage( DefaultTarget ) ) )
  end

  def test_psOptionPdfTarget
    Rant::TestUtil.write_to_file( RantfileName , PsOptionSourceRantfile )
    out , err = assert_rant( :fail , PdfTarget )
    assert( err.include?( "Don't know how to make `#{PdfTarget}'" ) )
  end

  def test_psOptionPsTarget
    Rant::TestUtil.write_to_file( RantfileName , PsOptionSourceRantfile )
    out , err = assert_rant( PsTarget )
    assert( File.exists?( PsTarget ) )
  end

  def test_psOptionErrorTarget
    Rant::TestUtil.write_to_file( RantfileName , PsOptionSourceRantfile )
    out , err = assert_rant( :fail , ErrorTarget )
    assert( err.include?( "Don't know how to make `#{ErrorTarget}'" ) )
  end

end
