require File.expand_path(File.dirname(__FILE__) + '/csharp_test_helper')
require File.expand_path(File.dirname(__FILE__) + 
    '/../../../lib/rant/csharp/gmcs_compiler')

class TestGmcsCompiler < Test::Unit::TestCase
  def setup
    @c = Rant::CSharp::GmcsCompiler.new
  end

  # Tests
  def test_initialize_should_provide_gmcs_bin
    assert_equal "gmcs", @c.bin
  end

  def test_initialize_should_allow_alternate_bin
    c = Rant::CSharp::GmcsCompiler.new("altbin")
    assert_equal "altbin", c.bin
  end
end
