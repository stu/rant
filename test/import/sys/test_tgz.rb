
require 'test/unit'
require 'tutil'

$test_import_sys_dir ||= File.expand_path(File.dirname(__FILE__))

class TestImportSysTgz < Test::Unit::TestCase
    include Rant::TestUtil

    def setup
        # Ensure we run in test directory.
        Dir.chdir($test_import_sys_dir)
    end
    def test_unpack_tgz
        assert !test(?e, "pkg")
        begin
            out, err = assert_rant "-ftgz.rf"
            assert err.empty?
            assert !out.empty?
            assert out.split(/\n/).size < 3
            dirs = %w(pkg pkg/bin)
            files = %w(pkg/test.c pkg/test.h pkg/bin/test pkg/bin/test.o)
            dirs.each { |dir|
                assert test(?d, dir), "dir `#{dir}' missing"
            }
            files.each { |fn|
                src_fn = File.join "data", fn
                assert test(?f, fn), "file `#{fn}' missing"
                assert Rant::Sys.compare_file(fn, src_fn), "#{fn} corrupted"
            }
            actual = Rant::FileList["pkg", "pkg/**/*", "pkg/**/.*"]
            actual.shun ".", ".."
            assert_equal((files + dirs).sort, actual.sort)
        ensure
            Rant::Sys.rm_rf "pkg"
        end
    end
end
