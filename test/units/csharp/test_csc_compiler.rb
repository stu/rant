require File.expand_path(File.dirname(__FILE__) + '/../csharp_test_helper')
require File.expand_path(File.dirname(__FILE__) + 
    '/../../../lib/rant/csharp/csc_compiler')

class TestCscCompiler < Test::Unit::TestCase
  def setup
    @c = Rant::CSharp::CscCompiler.new
  end

  # Tests
  def test_initialize_should_provide_csc_bin
    assert_equal "csc /nologo", @c.bin
  end

  def test_initialize_should_allow_alternate_bin
    c = Rant::CSharp::CscCompiler.new("altbin")
    assert_equal "altbin", c.bin
  end

  def test_argument_prefix_should_be_slash
    assert_equal "/", @c.argument_prefix
  end
end
