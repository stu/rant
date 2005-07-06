
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

$testProjectRb1Dir = File.expand_path(File.dirname(__FILE__))

class TestProjectRb1 < Test::Unit::TestCase
    def setup
	@manifest = %w(bin lib test bin/wgrep lib/wgrep.rb
	    test/text test/tc_wgrep.rb README test_project_rb1.rb
	    rantfile.rb)
	# Ensure we run in test directory.
	Dir.chdir($testProjectRb1Dir) unless Dir.pwd == $testProjectRb1Dir
    end
    def teardown
	capture_std do
	    assert_equal(Rant.run(%w(clean)), 0)
	end
	manifest = @manifest.dup
	check_manifest "after clean: "
    end
    def check_manifest(msg_prefix = "")
	manifest = @manifest.dup
	Dir["**/*"].each { |e|
	    assert(manifest.reject! { |mf| mf == e } ,
		"#{msg_prefix}#{e} shouldn't exist according to manifest")
	}
	manifest.each { |e|
	    assert(false, "#{msg_prefix}#{e} missing according to manifest")
	}
    end
    def test_doc
	capture_std do
	    assert_equal(Rant.run(%w(doc)), 0)
	end
	assert(test(?d, "doc"),
	    "RDoc task should generate dir `doc'")
	assert(test(?f, "doc/index.html"),
	    "doc/index.html should exist after `doc'")
	fl = Dir["doc/files/**/*"]
	assert(fl.find { |f| f =~ /wgrep/ },
	    "lib/wgrep.rb should get documented")
	assert(fl.find { |f| f =~ /README/ },
	    "README should be in html docs")
    end
    def test_test
	capture_std do
	    assert_equal(0, Rant.run(%w(test)))
	end
    end
    def test_package
	capture_std do
	    assert_equal(0, Rant.run(%w(pkg)))
	end
	assert(test(?d, "packages"),
	    "task `pkg' should create dir `packages'")
	have_gem = false
	pkg_base = "packages/wgrep-1.0.0"
	begin
	    require 'rubygems'
	    have_gem = true
	rescue LoadError
	end
	if have_any_tar?
	    tar_fn = pkg_base + ".tar.gz"
	    assert(test(?f, tar_fn),
		"tar is available, so a tar.gz should have been built")
	    verify_tar "packages", "wgrep-1.0.0", ".tar.gz"
	else
	    puts "*** tar not available ***"
	end
	if have_any_zip?
	    assert(test(?f, pkg_base + ".zip"),
		"zip is available, so a zip should have been built")
	    verify_zip "packages", "wgrep-1.0.0", ".zip"
	else
	    puts "*** zip not available ***"
	end
	if have_gem
	    assert(test(?f, pkg_base + ".gem"),
		"gem is available, so a gem should have been built")
	else
	    puts "*** gem not available ***"
	end
    end
    def verify_tar(dir, pkg_base, ext)
	tar_fn = pkg_base + ext
	old_pwd = Dir.pwd
	FileUtils.cd dir
	tmp_dir = "_tmp_tar"
	tmp_dir.freeze
	FileUtils.mkdir tmp_dir
	FileUtils.cp tar_fn, tmp_dir
	FileUtils.cd tmp_dir do
            #`tar xzf #{tar_fn}`
            unpack_archive :tgz, tar_fn
	    assert(test(?d, pkg_base),
		"`#{pkg_base}' should be root directory of all files in tar")
	    FileUtils.cd pkg_base do
		check_manifest "tar content: "
	    end
	end
    ensure
	FileUtils.cd old_pwd unless Dir.pwd == old_pwd
	FileUtils.rm_rf tmp_dir
    end
    def verify_zip(dir, pkg_base, ext)
	zip_fn = pkg_base + ext
	old_pwd = Dir.pwd
	FileUtils.cd dir
	tmp_dir = "_tmp_zip"
	tmp_dir.freeze
	FileUtils.mkdir tmp_dir
	FileUtils.cp zip_fn, tmp_dir
	FileUtils.cd tmp_dir do
            #`unzip -q #{zip_fn}`
            unpack_archive :zip, zip_fn
	    assert(test(?d, pkg_base),
		"`#{pkg_base}' should be root directory of all files in zip")
	    FileUtils.cd pkg_base do
		check_manifest "zip content: "
	    end
	end
    ensure
	FileUtils.cd old_pwd unless Dir.pwd == old_pwd
	FileUtils.rm_rf tmp_dir
    end
    def test_rant_import
	require 'rant/import'
	out, err = capture_std do
	    assert_equal(0, Rant::RantImport.run(%w(--auto make)))
	end
	# TODO: some out, err checking
	
	# run the monolithic rant script
	out = `#{Rant::Env::RUBY} make -T`
	assert_equal(0, $?,
	    "imported `rant -T' should return 0")
	assert_match(/\bpkg\b/, out,
	    "imported `rant -T' should list described task `pkg'")
    ensure
	File.delete "make" if File.exist? "make"
    end
end
