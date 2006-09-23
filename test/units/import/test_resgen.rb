require File.expand_path(File.dirname(__FILE__) + '/../csharp_test_helper')
module Rant::Generators; end;

require File.expand_path(File.dirname(__FILE__) + 
  '/../../../lib/rant/import/resgen')

begin
  require 'mocha'

  class TestResgen < Test::Unit::TestCase
    def setup
      @resgen = Rant::Generators::Resgen  
    end

    def test_should_create_rule_gen
      rant = rule_gen_rant_mock(/(.+?)\.resources/)
      @resgen.rant_gen(rant, nil, [{}])
    end

    def test_should_use_namespace
      rant = rule_gen_rant_mock(/Rant\.Test\.(.+?)\.resources/)
      @resgen.rant_gen(rant, nil, [{:namespace => 'Rant.Test'}])
    end

    def test_should_use_build_dir
      rant = rule_gen_rant_mock(/build\/(.+?)\.resources/)
      @resgen.rant_gen(rant, nil, [{:build_dir => 'build'}])
    end

    def test_src_matches_resx
      rant = rule_gen_rant_mock do |src|
        "a.resx" == src.call("a.resources")[0]
      end
      @resgen.rant_gen(rant, nil, [{}])
    end

    def test_src_matches_resx_with_namespace
      rant = rule_gen_rant_mock do |src|
        "a/b.resx" == src.call("a.b.resources")[0]
      end
      @resgen.rant_gen(rant, nil, [{}])
    end

    def test_src_matches_resx_with_build_dir
      rant = rule_gen_rant_mock do |src|
        "a.resx" == src.call("build/a.resources")[0]
      end
      @resgen.rant_gen(rant, nil, [{:build_dir => "build"}])
    end

    def test_rule_should_call_shell_command
      task = Struct.new(:source, :name).new("source", "name")

      sys = mock()
      sys.expects(:sh).with("resgen /useSourcePath /compile source,name")
      
      context = mock()
      context.expects(:gen).yields(task)
      context.expects(:sys).returns(sys)
    
      rant = mock()
      rant.expects(:context).at_least_once.returns(context)

      @resgen.rant_gen(rant, nil, [{}])
    end
    
    # Helpers
    def rule_gen_rant_mock regex = nil
      context = mock()
      context.expects(:gen).with() do |klass, task|
        ret =   (klass == Rant::Generators::Rule)
        ret &&= (!regex || (task.keys[0].to_s == regex.to_s))
        ret &&= (!block_given? || yield(task.values[0]))
        ret
      end
      
      rant = mock()
      rant.expects(:context).returns(context)
      rant
    end
  end

  # Mocks
  class Rant::Generators::Rule
  end
end
