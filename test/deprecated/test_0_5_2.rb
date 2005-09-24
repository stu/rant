
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
end
