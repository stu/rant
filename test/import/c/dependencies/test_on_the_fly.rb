
require 'test/unit'
require 'tutil'

$testImportCDepDir ||= File.expand_path(File.dirname(__FILE__))

class TestImportCDependenciesOnTheFly < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir $testImportCDepDir
    end
    def teardown
	Dir.chdir $testImportCDepDir
	FileUtils.rm_f "c_dependencies"
	FileUtils.rm_rf Dir["*.t"]
    end
    def test_opts_without_filename
	open "rf.t", "w" do |f|
	    f << <<-EOF
	    file "bar.t" => "src/bar.c" do |t|
		sys.touch t.name
	    end
	    gen C::Dependencies,
		:sources => sys["src/*.c"],
		:search => "include"
	    source "c_dependencies"
	    EOF
	end
	assert_rant("-frf.t")
	assert(test(?f, "bar.t"))
	out, err = assert_rant("-frf.t")
	assert(out.strip.empty?)
	assert(err.strip.empty?)
	old_mtime = File.mtime "bar.t"
	timeout
	FileUtils.touch "src/abc"
	assert_rant("-frf.t")
	assert_equal(old_mtime, File.mtime("bar.t"))
	timeout
	FileUtils.touch "include/with space.h"
	assert_rant("-frf.t")
	assert(File.mtime("bar.t") > old_mtime)
    end
    def write(fn, content)
        open fn, "w" do |f|
            f.write content
        end
    end
    def test_md5
        write "include/a.tt", <<-EOF
            void abc(void);
        EOF
        write "a.tt", <<-EOF
            #include "a.tt"
        EOF
        write "rf.t", <<-EOF
            import "md5", "c/dependencies", "autoclean"
            gen C::Dependencies,
                :search => ["include"],
                :sources => ["a.tt", "include/a.tt"]
            gen Action do source "c_dependencies" end
            gen AutoClean
            file "a.out" => "a.tt" do |t|
                sys.cp t.source, t.name
            end
        EOF
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        assert(!out.empty?)
        assert(test(?f, "c_dependencies"))
        assert(test(?f, "a.out"))
        assert_equal(File.read("a.tt"), File.read("a.out"))
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        assert(out.empty?)
        write "include/a.tt", <<-EOF
            int abc(void);
        EOF
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        assert(!out.empty?)
        assert(test(?f, "c_dependencies"))
        assert(test(?f, "a.out"))
        assert_equal(File.read("a.tt"), File.read("a.out"))
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("-frf.t", "autoclean")
        assert(!test(?e, ".rant.meta"))
        assert(!test(?e, "a.out"))
        assert(test(?f, "include/a.tt"))
        assert(test(?f, "a.tt"))
    ensure
        FileUtils.rm_f %w(include/a.tt a.tt rf.t a.out .rant.meta)
    end
    @@case_insensitive_fs = nil
    def case_insensitive_fs?
        return @@case_insensitive_fs unless @@case_insensitive_fs.nil?
        Rant::Sys.touch "Case.t"
        if @@case_insensitive_fs = File.exist?("case.t")
            puts "\n*** testing on a case-insensitive filesystem ***"
            true
        else
            puts "\n*** testing on a case-sensitive filesystem ***"
            false
        end
    ensure
        Rant::Sys.rm_f %w(case.t)
    end
    def test_correct_case_md5
        write "include/a.tt", <<-EOF
            void abc(void);
        EOF
        write "a.tt", <<-EOF
            #include "A.tt"
        EOF
        write "rf.t", <<-EOF
            import "md5", "c/dependencies", "autoclean"
            gen C::Dependencies,
                :correct_case => true,
                :search => ["include"],
                :sources => ["a.tt", "include/a.tt"]
            gen Action do source "c_dependencies" end
            gen AutoClean
            file "a.out" => "a.tt" do |t|
                sys.cp t.source, t.name
            end
        EOF
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        assert(!out.empty?)
        assert(test(?f, "c_dependencies"))
        assert(test(?f, "a.out"))
        assert_equal(File.read("a.tt"), File.read("a.out"))
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        assert(out.empty?)
        write "include/a.tt", <<-EOF
            int abc(void);
        EOF
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        return unless case_insensitive_fs?
        assert(!out.empty?)
        assert(test(?f, "c_dependencies"))
        assert(test(?f, "a.out"))
        assert_equal(File.read("a.tt"), File.read("a.out"))
        out, err = assert_rant("-frf.t", "a.out")
        assert(err.empty?)
        assert(out.empty?)
        assert_rant("-frf.t", "autoclean")
        assert(!test(?e, ".rant.meta"))
        assert(!test(?e, "a.out"))
        assert(test(?f, "include/a.tt"))
        assert(test(?f, "a.tt"))
    ensure
        FileUtils.rm_f %w(include/a.tt a.tt rf.t a.out .rant.meta)
    end
end
