
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
	end
    end
end

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
    `#{Rant::Sys.sp(Rant::Env::RUBY)} #{Rant::Sys.sp(RANT_BIN)} #{args.flatten.arglist}`
end

def run_import(*args)
    `#{Rant::Sys.sp(Rant::Env::RUBY)} #{Rant::Sys.sp(RANT_IMPORT_BIN)} #{args.flatten.arglist}`
end

def run_ruby(*args)
    `#{Rant::Sys.sp(Rant::Env::RUBY)} #{args.flatten.arglist}`
end

$have_unzip = !!Rant::Env.find_bin("unzip")

$have_any_zip = nil
def have_any_zip?
    return $have_any_zip unless $have_any_zip.nil?
    if Rant::Env.have_zip?
        $have_any_zip = true
    else
        begin
            require 'zip/zip'
            $have_any_zip = true
        rescue LoadError
            begin
                require 'rubygems'
                require 'zip/zip'
                $have_any_zip = true
            rescue LoadError
		$have_any_zip = false
            end
        end
    end
    $have_any_zip
end
$have_any_tar = nil
def have_any_tar?
    return $have_any_tar unless $have_any_tar.nil?
    if Rant::Env.have_tar?
        $have_any_tar = true
    else
        begin
            require 'archive/tar/minitar'
            $have_any_tar = true
        rescue LoadError
            begin
                require 'rubygems'
                require 'archive/tar/minitar'
                $have_any_tar = true
            rescue LoadError
		$have_any_tar = false
            end
        end
    end
    $have_any_tar
end
