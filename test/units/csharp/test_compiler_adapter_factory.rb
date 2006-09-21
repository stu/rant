require File.expand_path(File.dirname(__FILE__) + '/csharp_test_helper')
require File.expand_path(File.dirname(__FILE__) + 
    '/../../../lib/rant/csharp/compiler_adapter_factory')

class TestCompilerAdapterFactory < Test::Unit::TestCase
  # Tests
  def test_should_create_compiler_from_bin_in_path
    c = Rant::CSharp::CompilerAdapterFactory.new(mock_context(MockEnv.new))
    c.compiler_map = {"testbin" => MockCompiler }
    
    assert c.compiler.kind_of?(MockCompiler),
        "Compiler was not an instance of MockCompiler"
  end

  def test_should_raise_exception_if_no_compiler_found
    mock_context = Struct.new(:env).new(MockEnvNoBin.new)
    c = Rant::CSharp::CompilerAdapterFactory.new(mock_context(MockEnvNoBin.new))
    assert_raise(Exception) { c.compiler }
  end

  def test_should_cache_compiler
    mock_context = Struct.new(:env).new(MockEnv.new)
    c = ::Rant::CSharp::CompilerAdapterFactory.new(mock_context)
    c.compiler_map = {"testbin" => MockCompiler }
    
    c.compiler # First call to populate cache
    c.compiler_map = nil
    
    assert c.compiler.kind_of?(MockCompiler), 
        "Complier was not cached"
  end
  
  def test_should_have_valid_default_compiler_map
    c = Rant::CSharp::CompilerAdapterFactory.new(nil)
    
    assert c.compiler_map.respond_to?("[]"), "Default compiler map is invalid"
    c.compiler_map.each_pair do |key, value|
      assert value.respond_to?(:new), 
          "Default compiler map contains an invalid pair: #{key} => #{value}"
    end
  end

  # Helpers
  def mock_context(env)
    Struct.new(:env).new(env)
  end
  
  # Mocks
  class MockEnv
    def find_bin(bin)
      bin == "testbin"
    end
  end

  class MockEnvNoBin
    def find_bin(bin)
      false
    end
  end
  
  class MockCompiler
    def initialize context
    end
  end
end

