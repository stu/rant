
require 'test/unit'
require 'tutil'

$test_deprecated_dir ||= File.expand_path(File.dirname(__FILE__))

class TestDeprecated_0_5_2 < Test::Unit::TestCase
    include Rant::TestUtil

    def setup
        Dir.chdir $test_deprecated_dir
    end
    def test_method_rac
        in_local_temp_dir do
            write_to_file "root.rant", <<-EOF
                import "sys/more"
                file "f" do |t|
                    sys.write_to_file t.name, "nix"
                end
                task :a do
                    rac.build "f"
                end
            EOF
            out, err = assert_rant("a")
            assert test(?f, "f")
            assert_equal "nix", File.read("f")
            assert_match(/\bWARNING\b/, err)
            assert_match(/\brac\b/, err)
            assert_match(/\brant\b/, err)
            assert_match(/\bdeprecated\b/, err)
        end
    end
    def test_ary_arglist
        in_local_temp_dir do
            write_to_file "Rantfile", <<-EOF
                task :default do
                    sys(sys.sp(Env::RUBY_EXE) + " -e \\"puts ARGV\\" " +
                        ["a b", "c/d"].arglist + " > a.out")
                end
            EOF
            out, err = assert_rant
            content = Rant::Env.on_windows? ? "a b\nc\\d\n" : "a b\nc/d\n"
            assert_file_content "a.out", content
            assert_match(/\bWARNING\b/, err)
            assert_match(/\barglist\b/, err)
            assert_match(/\bsp\b/, err)
            assert_match(/\bdeprecated\b/, err)
        end
    end
    def test_ary_shell_pathes
        out, err = capture_std do
            sp = ["a b", "a/b"].shell_pathes
            assert sp.respond_to?(:to_ary)
            assert_equal 2, sp.size
        end
        assert_match(/\bWARNING\b/, err)
        assert_match(/\bshell_pathes\b/, err)
        assert_match(/\bsp\b/, err)
        assert_match(/\bdeprecated\b/, err)
    end
end
