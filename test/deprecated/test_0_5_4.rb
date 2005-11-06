
require 'test/unit'
require 'tutil'
require 'rant/import/sys/more'

$test_deprecated_dir ||= File.expand_path(File.dirname(__FILE__))

class TestDeprecated_0_5_4 < Test::Unit::TestCase
    include Rant::TestUtil

    def setup
        Dir.chdir $test_deprecated_dir
    end
    def test_autoimport_var_constraints
        Rant::Sys.write_to_file "var.t", <<-EOF
            var :a, :Integer
            var :b, :String
            var :c, :List
            var :d, :Bool
            task :default do
                p var[:a].kind_of?(Integer)
                p var[:b].kind_of?(String)
                p var[:c].kind_of?(Array)
                p(var[:d] == true || var[:d] == false)
            end
        EOF
        out, err = assert_rant "-fvar.t", "a=2", "d=1"
        assert_match(/import 'var\/numbers'/, err)
        assert_match(/import 'var\/strings'/, err)
        assert_match(/import 'var\/lists'/, err)
        assert_match(/import 'var\/booleans'/, err)
        lines = out.split(/\n/)
        assert_equal %w(true true true true), lines
    ensure
        Rant::Sys.rm_f "var.t"
    end
    def test_var_is
        Rant::Sys.write_to_file "var.t", <<-EOF
            import "var/booleans"
            var(:b => true).is :Bool
            task :default do
                p var[:b]
                var[:b] = "off"
                p var[:b]
            end
        EOF
        out, err = assert_rant("-fvar.t")
        assert_match(/\bvar\.t\b.*\b2\b.*var\.is.*deprecated.*0\.5\.4/m, err)
        assert_equal %w(true false), out.split(/\n/)
    ensure
        Rant::Sys.rm_f "var.t"
    end
end
