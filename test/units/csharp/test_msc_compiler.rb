require File.expand_path(File.dirname(__FILE__) + '/csharp_test_helper')
require File.expand_path(File.dirname(__FILE__) + 
    '/../../../lib/rant/csharp/mcs_compiler')

class TestMcsCompiler < Test::Unit::TestCase
  def setup
    @c = Rant::CSharp::McsCompiler.new
  end

  # Tests
  def test_initialize_should_provide_mcs_bin
    assert_equal "mcs", @c.bin
  end

  def test_initialize_should_allow_alternate_bin
    c = Rant::CSharp::McsCompiler.new("altbin")
    assert_equal "altbin", c.bin
  end

  def test_argument_prefix_should_be_dash
    assert_equal "-", @c.argument_prefix
  end
end
