
require 'test/unit'
require 'tutil'

$test_deprecated_dir ||= File.expand_path(File.dirname(__FILE__))

class TestDeprecated_0_4_8 < Test::Unit::TestCase
    include Rant::TestUtil

    def setup
        Dir.chdir $test_deprecated_dir
    end
    def test_Rantfile_rb
        in_local_temp_dir do
            write_to_file "Rantfile.rb", <<-EOF
                task :a do |t|
                    puts t.name
                end
            EOF
            out, err = assert_rant
            assert_equal("a\n", out)
            assert_match(/\bWARNING\b/, err)
            assert_match(/\bRantfile\.rb\b/, err)
            assert_match(/\bdeprecated\b/, err)
        end
    end
    def test_rantfile_rb
        in_local_temp_dir do
            write_to_file "Rantfile.rb", <<-EOF
                task :a do |t|
                    puts t.name
                end
            EOF
            out, err = assert_rant
            assert_equal("a\n", out)
            assert_match(/\bWARNING\b/, err)
            assert_match(/\bRantfile\.rb\b/, err)
            assert_match(/\bdeprecated\b/, err)
        end
    end
end
