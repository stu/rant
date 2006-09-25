require File.expand_path(File.dirname(__FILE__) + '/../csharp_test_helper')
module Rant::Generators; end;

require File.expand_path(File.dirname(__FILE__) + 
  '/../../../lib/rant/import/csharp')

begin
  require 'mocha'

  class TestCSharp < Test::Unit::TestCase
    def setup
      @csharp = Rant::Generators::CSharp  
    end
   
    # Tests
    def test_should_require_sources
      rant = mock()
      rant.expects(:abort_at
         ).with({}, "CSharp requires sources"
         ).raises(Exception
         ).times(2)
      
      assert_raise(Exception) {
        @csharp.rant_gen(rant, {}, ["target", {}])
      }
  
      assert_raise(Exception) {
        @csharp.rant_gen(rant, {}, ["target", {:sources => []}])
      } 
    end
  
    def test_should_require_target
      rant = mock()
      rant.expects(:abort_at
         ).with({}, "CSharp requires a target"
         ).raises(Exception)

      assert_raise(Exception) {
        @csharp.rant_gen(rant, {}, ["", {:sources => ["a"]}])
      }  
    end
    
    def test_should_create_file_task_depending_on_sources
      rant = mock()
      rant.expects(:file
         ).with({"target" => ["a"]})
    
      @csharp.rant_gen(rant, nil, ["target", {:sources => ["a"]}])
    end

    def test_file_task_should_depend_on_resources
      rant = mock()
      rant.expects(:file
         ).with({"target" => ["a", "b"]})
    
      @csharp.rant_gen(rant, nil, ["target", {:sources => ["a"], 
                                              :resources => ["b"]}])
    end

    def test_file_task_should_depend_on_libs
      rant = mock()
      rant.expects(:file
         ).with({"target" => ["a", "b"]})
    
      @csharp.rant_gen(rant, nil, ["target", {:sources => ["a"], 
                                              :libs => ["b"]}])
    end
    
    def test_file_task_should_call_shell_command
      sys = mock()
      sys.expects(:sh).with("command")
      
      context = mock()
      context.expects(:sys).returns(sys)
    
      rant = mock()
      rant.expects(:file).yields("target")
      rant.expects(:context).at_least_once.returns(context)

      compiler = mock()
      compiler.expects(:cmd).returns("command")
      
      @csharp.rant_gen(rant, nil, ["target", {:sources => ["a"], 
                                              :compiler => compiler}])
    end

    def test_get_compiler_should_use_given_compiler
      compiler = Object.new
    
      assert_equal compiler, 
                   @csharp.get_compiler(nil, {:compiler => compiler}),
                   "Does not use given compiler"
    end

    def test_get_compiler_should_create_instance_of_given_compiler_class
      klass = Class.new(Object)
      ret = @csharp.get_compiler(nil, {:compiler => klass})
      assert ret.kind_of?(klass), 
         "Created compiler was of class #{ret.class}, should have been #{klass}"
    end

    def test_get_compiler_should_remove_compiler_from attributes
      args = {:compiler => Object}
      @csharp.get_compiler(nil, args)
      assert args.empty?, ":compiler should have been removed from arguments"
    end

    def test_get_compiler_should_use_default_if_no_compiler_specified
      assert_equal "default_compiler", @csharp.get_compiler(nil, {})
    end
  end

  # Mocks
  class Rant::Generators::CSharp
    class MockFactory
      def compiler context
        "default_compiler"
      end
    end
    
    def self.compiler_adapter_factory
      MockFactory.new
    end
  end
rescue LoadError
  print "**** Could not test CSharp, requires mocha libary ****\n"
end
