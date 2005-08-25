
# This file contains methods that aid in testing Rant.

require 'rant/rantlib'
require 'fileutils'

module Test
    module Unit
	class TestCase
	    def assert_rant(*args)
		res = 0
		capture = true
                newproc = false
		args.flatten!
		args.reject! { |arg|
		    if Symbol === arg
			case arg
			when :fail: res = 1
			when :v: capture = false
			when :verbose: capture = false
                        when :x: newproc = true
			else
			    raise "No such option -- #{arg}"
			end
			true
		    else
			false
		    end
		}
                if newproc
                    if capture
                        # TODO: stderr
                        `#{Rant::Sys.sp(Rant::Env::RUBY)} #{Rant::Sys.sp(RANT_BIN)} #{args.flatten.join(' ')}`
                    else
                        system("#{Rant::Sys.sp(Rant::Env::RUBY)} " +
                            #{Rant::Sys.sp(RANT_BIN)} " +
                            "#{args.flatten.join(' ')}")
                    end
                    assert_equal(res, $?.exitstatus)
                end
		if capture
		    capture_std do
			assert_equal(res, ::Rant::RantApp.new.run(*args))
		    end
		else
		    assert_equal(res, ::Rant::RantApp.new.run(*args))
		end
	    end
            def assert_exit(status = 0)
                assert_equal(status, $?.exitstatus)
            end
            if RUBY_VERSION < "1.8.1"
                def assert_raise(*args, &block)
                    assert_raises(*args, &block)
                end
            end
	end # class TestCase
    end # module Unit
end # module Test

RANT_BIN = File.expand_path(
    File.join(File.dirname(__FILE__), "..", "run_rant"))

RANT_IMPORT_BIN = File.expand_path(
    File.join(File.dirname(__FILE__), "..", "run_import"))

RANT_DEV_LIB_DIR = File.expand_path(
    File.join(File.dirname(__FILE__), "..", "lib"))

$rant_test_to = Rant::Env.on_windows? ? 3 : 2
if ENV["TO"]
    begin
	$rant_test_to = Integer(ENV["TO"])
    rescue
    end
end

def timeout
    sleep $rant_test_to
end

# Everything written to $stdout during +yield+ will be returned. No
# output to $stdout.
def capture_stdout
    tfn = "._ranttestcstdout.tmp"
    if File.exist? tfn
	raise <<-EOD
When testing Rant: `#{Dir.pwd + "/" + tfn}' exists.
  The testing process temporarily needs this file. Ensure that the
  file doesn't contain data useful for you and try to remove it.
  (Perhaps this file was left by an earlier testrun.)
	EOD
    end
    begin
	stdout = $stdout
	File.open(tfn, "w") { |tf|
	    $stdout = tf
	    yield
	}
	o = File.read tfn
    ensure
	$stdout = stdout
	File.delete tfn if File.exist? tfn
    end
end

def capture_stderr
    tfn = "._ranttestcstderr.tmp"
    if File.exist? tfn
	raise <<-EOD
When testing Rant: `#{Dir.pwd + "/" + tfn}' exists.
  The testing process temporarily needs this file. Ensure that the
  file doesn't contain data useful for you and try to remove it.
  (Perhaps this file was left by an earlier testrun.)
	EOD
    end
    begin
	stderr = $stderr
	File.open(tfn, "w") { |tf|
	    $stderr = tf
	    yield
	}
	o = File.read tfn
    ensure
	$stderr = stderr
	File.delete tfn if File.exist? tfn
    end
end

def capture_std
    outfn = "._ranttestcstdout.tmp"
    errfn = "._ranttestcstderr.tmp"
    if File.exist? outfn
	raise <<-EOD
When testing Rant: `#{Dir.pwd + "/" + outfn}' exists.
  The testing process temporarily needs this file. Ensure that the
  file doesn't contain data useful for you and try to remove it.
  (Perhaps this file was left by an earlier testrun.)
	EOD
    end
    if File.exist? errfn
	raise <<-EOD
When testing Rant: `#{Dir.pwd + "/" + errfn}' exists.
  The testing process temporarily needs this file. Ensure that the
  file doesn't contain data useful for you and try to remove it.
  (Perhaps this file was left by an earlier testrun.)
	EOD
    end
    begin
	stdout = $stdout
	stderr = $stderr
	File.open(outfn, "w") { |of|
	    $stdout = of
	    File.open(errfn, "w") { |ef|
		$stderr = ef
		yield
	    }
	}
	[File.read(outfn), File.read(errfn)]
    ensure
	$stderr = stderr
	$stdout = stdout
	File.delete outfn if File.exist? outfn
	File.delete errfn if File.exist? errfn
    end
end

def run_rant(*args)
    `#{Rant::Sys.sp(Rant::Env::RUBY)} #{Rant::Sys.sp(RANT_BIN)} #{args.flatten.join(' ')}`
end

def run_import(*args)
    `#{Rant::Sys.sp(Rant::Env::RUBY)} #{Rant::Sys.sp(RANT_IMPORT_BIN)} #{args.flatten.join(' ')}`
end

def run_ruby(*args)
    `#{Rant::Sys.sp(Rant::Env::RUBY)} #{args.flatten.join(' ')}`
end

$have_unzip = !!Rant::Env.find_bin("unzip")

def unpack_archive(atype, archive)
    case atype
    when :tgz
        if ::Rant::Env.have_tar?
            `tar -xzf #{archive}`
        else
            minitar_unpack archive
        end
    when :zip
        if $have_unzip
            `unzip -q #{archive}`
        else
            rubyzip_unpack archive
        end
    else
        raise "can't unpack archive type #{atype}"
    end
end
def minitar_unpack(archive)
    require 'zlib'
    require 'rant/archive/minitar'
    tgz = Zlib::GzipReader.new(File.open(archive, 'rb'))
    # unpack closes tgz
    Rant::Archive::Minitar.unpack(tgz, '.')
end
def rubyzip_unpack(archive)
    require 'rant/archive/rubyzip'
    f = Rant::Archive::Rubyzip::ZipFile.open archive
    f.entries.each { |e|
        dir, = File.split(e.name)
        FileUtils.mkpath dir unless test ?d, dir
        f.extract e, e.name
    }
    f.close
end

# Returns a list with the files required by the IO object script.
def extract_requires(script, dynamic_requires = [])
    in_ml_comment = false
    requires = []
    script.each { |line|
        if in_ml_comment
            if line =~ /^=end/
                in_ml_comment = false
            end
            next
        end
        # skip shebang line
        next if line =~ /^#! ?(\/|\\)?\w/
        # skip pure comment lines
        next if line =~ /^\s*#/
        if line =~ /^=begin\s/
            in_ml_comment = true
            next
        end
        name = nil
        lib_file = nil
        if line =~ /\s*(require|load)\s*('|")([^\2]*)\2/
            fn = $3
            if fn =~ /\#\{[^\}]+\}/ || fn =~ /\#\@/
                dynamic_requires << fn
            else
                requires << fn
            end
        end
    }
    requires
end

module Rant::TestUtil
    def in_local_temp_dir(dirname = "t")
        dirname = dirname.dup
        base_dir = Dir.pwd
        raise "dir `#{t}' already exists" if test ?e, dirname
        FileUtils.mkdir dirname
        Dir.chdir dirname
        yield
    ensure
        Dir.chdir base_dir
        FileUtils.rm_rf dirname
    end
    def write_to_file(fn, content)
        open fn, "w" do |f|
            f.write content
        end
    end
    extend self
end
