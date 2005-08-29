
require 'test/unit'
require 'tutil'

$test_import_sys_dir ||= File.expand_path(File.dirname(__FILE__))

class TestImportSysZip < Test::Unit::TestCase
    include Rant::TestUtil

    def setup
        # Ensure we run in test directory.
        Dir.chdir($test_import_sys_dir)
    end
    def test_unpack_zip_in_dir
        assert !test(?e, "dir.t")
        out, err = assert_rant "-fzip.rf"
        assert err.empty?
        assert !out.empty?
        assert test(?f, "t.zip")
        assert out.split(/\n/).size < 6
        dirs = %w(pkg pkg/bin)
        files = %w(pkg/test.c pkg/test.h pkg/bin/test pkg/bin/test.o)
        dirs.each { |dir|
            dir = File.join("dir.t", dir)
            assert test(?d, dir), "dir `#{dir}' missing"
        }
        files.each { |fn|
            src_fn = File.join "data", fn
            fn = File.join("dir.t", fn)
            assert test(?f, fn), "file `#{fn}' missing"
            assert Rant::Sys.compare_file(fn, src_fn), "#{fn} corrupted"
        }
        actual = Rant::FileList["dir.t/**/*", "dir.t/**/.*"]
        actual.shun ".", ".."
        actual.map! { |e| e.sub(/^dir\.t\//, '') }
        assert_equal((files + dirs).sort, actual.sort)
        out, err = assert_rant "-fzip.rf"
        assert err.empty?
        assert out.empty?
        out, err = assert_rant "-fzip.rf", "src=data/pkg2.zip"
        assert err.empty?
        assert !out.empty?
        assert out.split(/\n/).size < 6
        dirs = %w(pkg pkg/bin)
        files = %w(pkg/test.c pkg/test.h pkg/bin/test)
        dirs.each { |dir|
            dir = File.join("dir.t", dir)
            assert test(?d, dir), "dir `#{dir}' missing"
        }
        files.each { |fn|
            src_fn = File.join "data", fn
            fn = File.join("dir.t", fn)
            assert test(?f, fn), "file `#{fn}' missing"
            assert Rant::Sys.compare_file(fn, src_fn), "#{fn} corrupted"
        }
        actual = Rant::FileList["dir.t/**/*", "dir.t/**/.*"]
        actual.shun ".", ".."
        actual.map! { |e| e.sub(/^dir\.t\//, '') }
        assert_equal((files + dirs).sort, actual.sort)
        out, err = assert_rant "-fzip.rf", "src=data/pkg2.zip"
        assert err.empty?
        assert out.empty?
        assert_rant "-fzip.rf", "autoclean"
        assert !test(?e, "dir.t")
        assert !test(?e, "t.zip")
        assert Dir["**/*.rant.meta"].empty?
    end
end
