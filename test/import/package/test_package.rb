
require 'test/unit'
require 'tutil'

$testIPackageDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportPackage < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testIPackageDir
    end
    def check_contents(atype, archive, files, dirs = [], manifest_file = nil)
	FileUtils.mkdir "u.t"
	FileUtils.mv archive, "u.t"
	FileUtils.cd "u.t"
	archive = File.basename archive
	unpack_archive atype, archive
	files.each { |f| assert(test(?f, f)) }
	dirs.each { |f| assert(test(?d, f)) }
	# + 1 because of the archive file
	assert_equal((files + dirs).size + 1, Dir["**/*"].size)
	if manifest_file
	    check_manifest(manifest_file, files)
	end
	yield if block_given?
    ensure
	FileUtils.cd ".."
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
    def unpack_archive(atype, archive)
	case atype
	when :tgz
	    `tar -xzf #{archive}`
	when :zip
	    `unzip -q #{archive}`
	else
	    raise "can unpack archive type #{atype}"
	end
    end
if Rant::Env.have_tar?
    def test_tgz_from_manifest
	assert_rant("t1.tgz")
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
    ensure
	FileUtils.rm_f "m2.tgz.t"
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
end
if Rant::Env.have_zip?
    def test_zip_from_manifest
	assert_rant("t1.zip")
	mf = %w(Rantfile sub/f1 sub2/f1 MANIFEST)
	dirs = %w(sub sub2)
	check_contents(:zip, "t1.zip", mf, dirs, "MANIFEST")
    end
    def test_zip_sync_manifest
	assert_rant("t2.zip")
	mf = %w(sub/f1 sub2/f1 m2.zip.t)
	dirs = %w(sub sub2)
	check_manifest("m2.zip.t", mf)
	check_contents(:zip, "t2.zip", mf, dirs, "m2.zip.t")
    ensure
	FileUtils.rm_f "m2.zip.t"
    end
    def test_zip_filelist
	assert_rant("t3.zip")
	mf = %w(Rantfile sub/f1)
	dirs = %w(sub)
	check_contents(:zip, "t3.zip", mf, dirs)
    end
end
    def test_dummy
	assert(true)
    end
end
