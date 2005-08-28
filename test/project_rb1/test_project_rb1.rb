
require 'test/unit'
require 'tutil'

$testProjectRb1Dir = File.expand_path(File.dirname(__FILE__))

class TestProjectRb1 < Test::Unit::TestCase
    def setup
	@manifest = %w(bin lib test bin/wgrep lib/wgrep.rb
	    test/text test/tc_wgrep.rb README test_project_rb1.rb
	    rantfile)
	# Ensure we run in test directory.
	Dir.chdir($testProjectRb1Dir)
    end
    def teardown
        assert_rant("clean")
	manifest = @manifest.dup
	check_manifest "after clean: "
    end
    def check_manifest(msg_prefix = "")
	manifest = @manifest.dup
        #Dir["**/*"].each { |e|
        Rant::FileList["**/*"].shun(".svn").each { |e|
	    assert(manifest.reject! { |mf| mf == e } ,
		"#{msg_prefix}#{e} shouldn't exist according to manifest")
	}
	manifest.each { |e|
	    assert(false, "#{msg_prefix}#{e} missing according to manifest")
	}
    end
    def test_doc
        have_rdoc = true
        begin
            require 'rdoc/rdoc'
        rescue LoadError
            have_rdoc = false
        end
        if have_rdoc
            assert_rant("doc")
            assert(test(?d, "doc"),
                "RDoc task should generate dir `doc'")
            assert(test(?f, "doc/index.html"),
                "doc/index.html should exist after `doc'")
            fl = Dir["doc/files/**/*"]
            assert(fl.find { |f| f =~ /wgrep/ },
                "lib/wgrep.rb should get documented")
            assert(fl.find { |f| f =~ /README/ },
                "README should be in html docs")
        else
            STDERR.puts "*** rdoc not available ***"
            out, err = assert_rant(:fail, "doc")
            lines = err.split(/\n/)
            lines.reject! { |s| s.strip.empty? }
            assert_equal(4, lines.size)
            assert_match(/ERROR.*in file.*line \d+/, lines[0])
            assert_match(/RDoc not available/, lines[1])
            assert_match(/doc.*fail/, lines[2])
        end
    end
    def test_test
        assert_rant("test")
    end
    def test_package
        assert_rant("pkg")
	assert(test(?d, "packages"),
	    "task `pkg' should create dir `packages'")
	have_gem = false
	pkg_base = "packages/wgrep-1.0.0"
	begin
	    require 'rubygems'
	    have_gem = true
	rescue LoadError
	end
        tar_fn = pkg_base + ".tar.gz"
        assert(test(?f, tar_fn),
            "tar is available, so a tar.gz should have been built")
        verify_tar "packages", "wgrep-1.0.0", ".tar.gz"
	    assert(test(?f, pkg_base + ".zip"),
		"zip is available, so a zip should have been built")
	    verify_zip "packages", "wgrep-1.0.0", ".zip"
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
            Rant::Sys.unpack_tgz tar_fn
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
            Rant::Sys.unpack_zip zip_fn
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
        #out = `#{Rant::Env::RUBY} make -T`
        out = run_ruby("make", "-T")
	assert_equal(0, $?,
	    "imported `rant -T' should return 0")
	assert_match(/\bpkg\b/, out,
	    "imported `rant -T' should list described task `pkg'")
    ensure
        FileUtils.rm_f "make"
    end
end
