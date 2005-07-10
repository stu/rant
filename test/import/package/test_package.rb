
require 'test/unit'
require 'tutil'

$testIPackageDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportPackage < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testIPackageDir
	@pkg_dir = nil
        @contents = {}
    end
    def teardown
	assert_rant("autoclean")
	Dir["*.{tgz,zip,t}"].each { |f|
            assert(false, "#{f} should be removed by AutoClean")
        }
    end
    def check_contents(atype, archive, files, dirs = [], manifest_file = nil)
	old_pwd = Dir.pwd
	FileUtils.mkdir "u.t"
	FileUtils.cp archive, "u.t"
	FileUtils.cd "u.t"
	archive = File.basename archive
	unpack_archive atype, archive
	if @pkg_dir
	    assert(test(?d, @pkg_dir))
	    FileUtils.cd @pkg_dir
	end
	files.each { |f|
            assert(test(?f, f), "file #{f} is missing in archive")
            content = @contents[f]
            if content
                assert_equal(content, File.read(f))
            end
	}
	dirs.each { |f|
	    assert(test(?d, f), "dir #{f} is missing in archive")
	}
	count = files.size + dirs.size
	# + 1 because of the archive file
	count += 1 unless @pkg_dir
	assert_equal(count, Dir["**/*"].size)
	if manifest_file
	    check_manifest(manifest_file, files)
	end
	yield if block_given?
    ensure
	FileUtils.cd old_pwd
	FileUtils.rm_r "u.t"
    end
    def check_manifest(file, entries)
	assert(test(?f, file))
	m_entries = IO.read(file).split("\n")
	assert_equal(entries.size, m_entries.size)
	entries.each { |f|
	    assert(m_entries.include?(f),
		"#{f} missing in manifest")
	}
    end
    def test_tgz_from_manifest
	assert_rant
	mf = %w(Rantfile sub/f1 sub2/f1 MANIFEST)
	dirs = %w(sub sub2)
	check_contents(:tgz, "t1.tgz", mf, dirs, "MANIFEST")
    end
    def test_tgz_sync_manifest
	assert_rant("t2.tgz")
	mf = %w(sub/f1 sub2/f1 m2.tgz.t)
	dirs = %w(sub sub2)
	check_manifest("m2.tgz.t", mf)
	check_contents(:tgz, "t2.tgz", mf, dirs, "m2.tgz.t")
	out, err = assert_rant("t2.tgz")
	assert(out.strip.empty?)
	#assert(err.strip.empty?)
	FileUtils.touch "sub/f5"
	out, err = assert_rant("t2.tgz")
	assert_match(/writing m2\.tgz\.t.*\n.*tar/m, out)
	check_contents(:tgz, "t2.tgz", mf + %w(sub/f5), dirs, "m2.tgz.t")
	timeout
	FileUtils.rm "sub/f5"
	out, err = assert_rant("t2.tgz")
	assert_match(/writing m2\.tgz\.t.*\n.*tar/m, out)
	check_contents(:tgz, "t2.tgz", mf, dirs, "m2.tgz.t")
	# test autoclean
	assert_rant("autoclean")
	assert(!test(?e, "m2.tgz.t"))
	# hmm.. the tgz will be removed by check_contents anyway...
	assert(!test(?e, "t2.tgz"))
    ensure
	FileUtils.rm_rf "sub/f5"
    end
    def test_tgz_files_array
	assert_rant("t3.tgz")
	mf = %w(Rantfile sub/f1)
	dirs = %w(sub)
	check_contents(:tgz, "t3.tgz", mf, dirs)
    end
    def test_tgz_version_and_dir
	assert_rant("pkg.t/t4-1.0.0.tgz")
	assert(test(?d, "pkg.t"))
	mf = %w(Rantfile sub/f1 sub2/f1 MANIFEST)
	dirs = %w(sub sub2)
	check_contents(:tgz, "pkg.t/t4-1.0.0.tgz", mf, dirs, "MANIFEST")
    ensure
	FileUtils.rm_rf "pkg.t"
    end
    def test_tgz_package_manifest
	assert(!test(?e, "pkg2.t"))
	assert_rant("pkg2.t.tgz")
	assert(?d, "pkg2.t")
	mf = %w(Rantfile sub/f1 sub2/f1 MANIFEST)
	dirs = %w(sub sub2)
	@pkg_dir = "pkg2.t"
	check_contents(:tgz, "pkg2.t.tgz", mf, dirs, "MANIFEST")
	assert(test(?d, "pkg2.t"))
	assert_rant("autoclean")
	assert(!test(?e, "pkg2.t"))
    end
    def test_tgz_package_basedir_manifest_extension
	assert_rant("sub/pkg.t/pkg-0.1.tar.gz")
	assert(test(?f, "sub/pkg.t/pkg-0.1.tar.gz"))
	mf = %w(Rantfile sub/f1 sub2/f1 MANIFEST)
	dirs = %w(sub sub2)
	@pkg_dir = "pkg-0.1"
	check_contents(:tgz,
	    "sub/pkg.t/pkg-0.1.tar.gz", mf, dirs, "MANIFEST")
	assert(test(?f, "sub/f1"))
	assert_rant("autoclean")
	assert(!test(?e, "sub/pkg.t-0.1"))
	assert(test(?d, "sub"))
	assert(test(?f, "sub/f1"))
    end
    def test_tgz_package_basedir_with_slash
	assert(!test(?d, "sub.t"))
	assert_rant(:fail, "sub.t/pkg.tgz")
	assert(!test(?d, "sub.t"))
	FileUtils.mkdir "sub.t"
	FileUtils.touch "sub.t/a.t"
	out, err = assert_rant("sub.t/pkg.tgz")
	assert(!out.empty?)
	out, err = assert_rant("sub.t/pkg.tgz")
	assert(out.empty?)
	assert(test(?d, "sub.t/pkg"))
	@pkg_dir = "pkg"
	mf = %w(sub/f1)
	dirs = %w(sub)
	check_contents(:tgz, "sub.t/pkg.tgz", mf, dirs)
	assert_rant("autoclean")
	assert(!test(?e, "sub.t/pkg.tgz"))
	assert(!test(?e, "sub.t/pkg"))
	assert(test(?d, "sub.t"))
	assert(test(?f, "sub.t/a.t"))
    ensure
	FileUtils.rm_rf "sub.t"
    end
    def test_tgz_import_archive
	open "rf.t", "w" do |f|
	    f << <<-EOF
		import "archive/tgz", "autoclean"
		gen Archive::Tgz, "rf", :files => sys["deep/sub/sub/f1"]
		gen AutoClean
	    EOF
	end
	assert_rant("-frf.t")
	mf = %w(deep/sub/sub/f1)
	dirs = %w(deep deep/sub deep/sub/sub)
	check_contents(:tgz, "rf.tgz", mf, dirs)
	assert(test(?f, "rf.tgz"))
	assert_rant("-frf.t", "autoclean")
	assert(!test(?e, "rf.tgz"))
	run_import("-frf.t", "-q", "--auto", "ant.t")
	assert_equal(0, $?.exitstatus)
	out = run_ruby("ant.t", "-frf.t")
	assert(!out.empty?)
	out = run_ruby("ant.t", "-frf.t")
	assert(out.empty?)
	check_contents(:tgz, "rf.tgz", mf, dirs)
	assert(test(?f, "rf.tgz"))
	assert_rant("-frf.t", "autoclean")
	assert(!test(?e, "rf.tgz"))
    ensure
	FileUtils.rm_rf %w(rf.t ant.t)
    end
    def test_tgz_package_empty_dir
	FileUtils.mkdir "sub6.t"
	assert_rant("t6.tgz")
	@pkg_dir = "t6"
	mf = %w()
	dirs = %w(sub6.t)
	check_contents(:tgz, "t6.tgz", mf, dirs)
    ensure
	FileUtils.rm_rf %w(sub6.t)
    end
    def test_tgz_files_manifest_desc
	out, err = assert_rant("--tasks")
	assert_match(/rant\s+t2\.tgz\s+#\s+Create t2\.tgz/, out)
    end
    def test_tgz_package_files_contains_manifest
	assert_rant("t5.tgz")
	@pkg_dir = "t5"
	mf = %w(Rantfile mf5.t)
	dirs = %w()
	check_contents(:tgz, "t5.tgz", mf, dirs, "mf5.t")
	assert_rant("autoclean")
	assert(!test(?e, "t5"))
    end
    def test_tgz_package_non_recursive
        FileUtils.mkdir "sub6.t"
        FileUtils.touch "sub6.t/.t"
        FileUtils.touch "sub6.t/a.t"
        assert_rant("t6.tgz")
        @pkg_dir = "t6"
        mf = %w()
        dirs = %w(sub6.t)
        check_contents(:tgz, "t6.tgz", mf, dirs)
        assert_rant("autoclean")
        assert(!test(?e, "t6"))
    ensure
        FileUtils.rm_rf "sub6.t"
    end
    def test_tgz_non_recursive
        FileUtils.mkdir "sub7.t"
        FileUtils.touch "sub7.t/a"
        assert_rant("t7.tgz")
        mf = %w()
        dirs = %w(sub7.t)
        check_contents(:tgz, "t7.tgz", mf, dirs)
    ensure
        FileUtils.rm_rf "sub7.t"
    end
    def test_tgz_follow_symlink
        have_symlinks = true
        FileUtils.mkdir "subs.t"
        open "target.t", "w" do |f|
            f.print "symlink test target file"
        end
        begin
            File.symlink "../target.t", "subs.t/symlink"
        rescue NotImplementedError
            have_symlinks = false
        end
        if have_symlinks
            assert(File.symlink?("subs.t/symlink"))
            assert(File.exist?("subs.t/symlink"))
            assert_rant("sym.tgz")
            mf = %w(subs.t/symlink)
            dirs = %w(subs.t)
            @contents["subs.t/symlink"] = "symlink test target file"
            check_contents(:tgz, "sym.tgz", mf, dirs)
        else
            STDERR.puts "*** platform doesn't support symbolic links ***"
        end
    ensure
        FileUtils.rm_f %w(target.t sym.tgz)
        FileUtils.rm_rf "subs.t"
    end
    def test_tgz_package_follow_symlink_dir
        have_symlinks = true
        FileUtils.mkdir "subs.t"
        begin
            File.symlink "subs.t", "sub6.t"
        rescue NotImplementedError
            have_symlinks = false
        end
        if have_symlinks
            assert_rant("t6.tgz")
            @pkg_dir = "t6"
            mf = %w()
            dirs = %w(sub6.t)
            check_contents(:tgz, "t6.tgz", mf, dirs)
        end
    ensure
        FileUtils.rm_rf %w(subs.t sub6.t)
    end
    def test_zip_follow_symlink
        have_symlinks = true
        FileUtils.mkdir "subs.t"
        open "target.t", "w" do |f|
            f.print "symlink test target file"
        end
        begin
            File.symlink "../target.t", "subs.t/symlink"
        rescue NotImplementedError
            have_symlinks = false
        end
        if have_symlinks
            assert(File.symlink?("subs.t/symlink"))
            assert(File.exist?("subs.t/symlink"))
            assert_rant("sym.zip")
            mf = %w(subs.t/symlink)
            dirs = %w(subs.t)
            @contents["subs.t/symlink"] = "symlink test target file"
            check_contents(:zip, "sym.zip", mf, dirs)
        else
            STDERR.puts "*** platform doesn't support symbolic links ***"
        end
    ensure
        FileUtils.rm_f %w(target.t sym.zip)
        FileUtils.rm_rf "subs.t"
    end
    def test_zip_package_follow_symlink_dir
        have_symlinks = true
        FileUtils.mkdir "subs.t"
        begin
            File.symlink "subs.t", "sub6.t"
        rescue NotImplementedError
            have_symlinks = false
        end
        if have_symlinks
            assert_rant("t6.zip")
            @pkg_dir = "t6"
            mf = %w()
            dirs = %w(sub6.t)
            check_contents(:zip, "t6.zip", mf, dirs)
        end
    ensure
        FileUtils.rm_rf %w(subs.t sub6.t)
    end
    def test_zip_non_recursive
        FileUtils.mkdir "sub7.t"
        FileUtils.touch "sub7.t/a"
        assert_rant("t7.zip")
        mf = %w()
        dirs = %w(sub7.t)
        check_contents(:zip, "t7.zip", mf, dirs)
    ensure
        FileUtils.rm_rf "sub7.t"
    end
    def test_zip_package_non_recursive
        FileUtils.mkdir "sub6.t"
        FileUtils.touch "sub6.t/.t"
        FileUtils.touch "sub6.t/a.t"
        assert_rant("t6.zip")
        @pkg_dir = "t6"
        mf = %w()
        dirs = %w(sub6.t)
        check_contents(:zip, "t6.zip", mf, dirs)
        assert_rant("autoclean")
        assert(!test(?e, "t6"))
    ensure
        FileUtils.rm_rf "sub6.t"
    end
    def test_zip_package_empty_dir
	FileUtils.mkdir "sub6.t"
	assert_rant("t6.zip")
	@pkg_dir = "t6"
	mf = %w()
	dirs = %w(sub6.t)
	check_contents(:zip, "t6.zip", mf, dirs)
    ensure
	FileUtils.rm_rf %w(sub6.t)
    end
    def test_zip_manifest_desc
	out, err = assert_rant("--tasks")
	assert_match(/rant\s+t1\.zip\s+#\s+Create t1\.zip/, out)
    end
    def test_zip_rant_import
	run_import("-q", "--auto", "ant.t")
	assert_equal(0, $?.exitstatus)
	assert(test(?f, "ant.t"))
	out = run_ruby("ant.t", "pkg.t/pkg.zip")
	assert_equal(0, $?.exitstatus)
	assert(!out.empty?)
	out = run_ruby("ant.t", "pkg.t/pkg.zip")
	assert(out.empty?)
	mf = %w(deep/sub/sub/f1 CONTENTS)
	dirs = %w(deep deep/sub deep/sub/sub)
	@pkg_dir = "pkg"
	check_contents(:zip, "pkg.t/pkg.zip", mf, dirs, "CONTENTS")
	assert(test(?f, "CONTENTS"))
	run_ruby("ant.t", "autoclean")
	assert(!test(?f, "CONTENTS"))
    ensure
	FileUtils.rm_f "ant.t"
    end
    def test_zip_package_write_manifest
	assert(!test(?f, "CONTENTS"))
	assert_rant(:x, "pkg.t/pkg.zip")
	assert(test(?f, "CONTENTS"))
	mf = %w(deep/sub/sub/f1 CONTENTS)
	dirs = %w(deep deep/sub deep/sub/sub)
	@pkg_dir = "pkg"
	check_contents(:zip, "pkg.t/pkg.zip", mf, dirs, "CONTENTS")
	assert(test(?f, "CONTENTS"))
	assert_rant("autoclean")
	assert(!test(?f, "CONTENTS"))
    end
    def test_zip_with_basedir
	assert_rant(:fail, "zip.t/t4-1.0.0.zip")
	assert(!test(?d, "zip.t"))
	FileUtils.mkdir "zip.t"
	assert_rant(:x, "zip.t/t4-1.0.0.zip")
	mf = %w(Rantfile sub/f1 sub2/f1 MANIFEST)
	dirs = %w(sub sub2)
	check_contents(:zip, "zip.t/t4-1.0.0.zip", mf, dirs, "MANIFEST")
	assert_rant("autoclean")
	assert(test(?d, "zip.t"))
	assert(!test(?e, "zip.t/t4-1.0.0.zip"))
    ensure
	FileUtils.rm_rf "zip.t"
    end
    def test_zip_from_manifest
	assert_rant(:x, "t1.zip")
	mf = %w(Rantfile sub/f1 sub2/f1 MANIFEST)
	dirs = %w(sub sub2)
	check_contents(:zip, "t1.zip", mf, dirs, "MANIFEST")
    end
    def test_zip_sync_manifest
	assert_rant(:x, "t2.zip")
	mf = %w(sub/f1 sub2/f1 m2.zip.t)
	dirs = %w(sub sub2)
	check_manifest("m2.zip.t", mf)
	check_contents(:zip, "t2.zip", mf, dirs, "m2.zip.t")
    ensure
	FileUtils.rm_f "m2.zip.t"
    end
    def test_zip_filelist
	assert_rant(:x, "t3.zip")
	mf = %w(Rantfile sub/f1)
	dirs = %w(sub)
	check_contents(:zip, "t3.zip", mf, dirs)
    end
end
