require File.expand_path(File.dirname(__FILE__) + '/../csharp_test_helper')
module Rant::Generators; end;

require File.expand_path(File.dirname(__FILE__) + 
  '/../../../lib/rant/import/nunittest')

begin
  require 'mocha'

  class TestNUnitTest < Test::Unit::TestCase
    def setup
      @nunit = Rant::Generators::NUnitTest  
    end
   
    # Tests
    def test_should_require_dlls
      rant = mock()
      rant.expects(:abort_at
         ).with({}, "NUnitTest requires dlls"
         ).raises(Exception
         ).times(2)
      
      assert_raise(Exception) {
        @nunit.rant_gen(rant, {}, ["target", {}])
      }
  
      assert_raise(Exception) {
        @nunit.rant_gen(rant, {}, ["target", {:dlls => []}])
      } 
    end
  
    def test_should_require_task_name
      rant = mock()
      rant.expects(:abort_at
         ).with({}, "NUnitTest requires a task name"
         ).raises(Exception)

      assert_raise(Exception) {
        @nunit.rant_gen(rant, {}, ["", {:dlls => ["a"]}])
      }  
    end

    def test_should_create_task
      rant = mock()
      rant.expects(:task)
    
      @nunit.rant_gen(rant, nil, ["target", {:dlls => ["a"]}])
    end

    def test_task_should_call_shell_command
      dll = "a"
      
      sys = mock()
      sys.expects(:sh).with("command a")
      sys.expects(:sp).returns(dll)
      
      context = mock()
      context.expects(:sys).returns(sys).at_least_once

      rant = mock()
      rant.expects(:task).yields("target")
      rant.expects(:context).at_least_once.returns(context)
      
      @nunit.rant_gen(rant, nil, ["target", {:dlls => dll, 
                                              :bin => "command"}])
    end

    def test_should_accept_dlls_as_filelist
      dll = mock()
      dll.expects(:arglist).returns("a")

      assert_equal "a", @nunit.process_dlls(nil, dll)
    end

    def test_should_accept_dlls_as_array
      dll = ["a", "a"]

      sys = mock()
      sys.expects(:sp).returns("a").times(2)
      
      context = mock()
      context.expects(:sys).returns(sys).at_least_once

      rant = mock()
      rant.expects(:context).at_least_once.returns(context)

      assert_equal "a a", @nunit.process_dlls(rant, dll)
    end

    def test_should_accept_dll_as_string
      dll = "a"

      sys = mock()
      sys.expects(:sp).returns("a").times(1)
      
      context = mock()
      context.expects(:sys).returns(sys).at_least_once

      rant = mock()
      rant.expects(:context).at_least_once.returns(context)

      assert_equal "a", @nunit.process_dlls(rant, dll)
    end

    def test_default_command_is_nunit_console
      sys = mock()
      sys.expects(:sp).returns("a").at_least_once
      sys.expects(:sh).returns("nunit-console /nologo a")
      
      context = mock()
      context.expects(:sys).returns(sys).at_least_once

      rant = mock()
      rant.expects(:task).yields("target")
      rant.expects(:context).at_least_once.returns(context)
                   
      @nunit.rant_gen(rant, nil, ["target", {:dlls => "a"}])
    end
  end
rescue LoadError
  print "**** Could not test NUnitTest, requires mocha libary ****\n"
end
