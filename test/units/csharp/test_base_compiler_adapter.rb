require File.expand_path(File.dirname(__FILE__) + '/../csharp_test_helper')
require File.expand_path(File.dirname(__FILE__) + 
    '/../../../lib/rant/csharp/base_compiler_adapter')

class TestBaseCompilerAdapter < Test::Unit::TestCase
  def setup
    @c = Rant::CSharp::BaseCompilerAdapter.new("testbin")
  end

  # Tests
  def test_initialize_should_fail_with_blank_bin
    assert_raise(Exception) { Rant::CSharp::BaseCompilerAdapter.new }
    assert_raise(Exception) { Rant::CSharp::BaseCompilerAdapter.new("") }
  end
  
  def test_cmd_should_fail_with_blank_target
    assert_raise(Exception) { @c.cmd("", nil, nil) }
  end

  def test_cmd_should_create_compile_line
    assert_equal "testbin out:outfile target:library ", 
                  @c.cmd("outfile", {}, mock_context)
  end

  def test_cmd_should_create_complex_compile_line
    args = {:sources => ["a", "b"], 
            :libs => ["c", "d"], 
            :target => "exe", 
            :checked => false}

    cmd = @c.cmd("outfile", args, mock_context)
    # Order of arguments is undefined, so use regex to test
    assert_regex "^testbin out:outfile "  , cmd
    assert_regex " target:exe "           , cmd 
    assert_regex " checked- "             , cmd
    assert_regex " libs:c libs:d "        , cmd
    assert_regex "a b$"                   , cmd         
  end
  
  def test_should_provide_default_map_target
    assert_equal "string 1", @c.map_target("string 1")
    assert_equal "string 2", @c.map_target("string 2")
  end

  def test_should_guess_module_target
    assert_equal "module", @c.guess_target("outfile.netmodule")
  end

  def test_should_guess_exe_target_as_winexe
    assert_equal "winexe", @c.guess_target("outfile.exe")
  end

  def test_should_default_to_library_target
    assert_equal "library", @c.guess_target("outfile.dll")
    assert_equal "library", @c.guess_target("outfile")
  end

  # Helpers
  def mock_context
    Struct.new(:sys).new(MockSys.new)
  end

  def assert_regex regex, actual
    assert actual =~ Regexp.new(regex), "<\"#{actual}\"> did not match /#{regex}/"
  end
  
  # Mocks
  class MockSys
    def sp(file)
      file
    end
  end
end
