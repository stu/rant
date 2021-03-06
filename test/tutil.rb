
# This file contains methods that aid in testing Rant.

$-w = true

require 'rant/rantlib'
require 'rant/import/sys/tgz'
require 'rant/import/sys/zip'
require 'fileutils'

module Test
    module Unit
	class TestCase
            def ext_rb_test(script, opts = {})
                out = nil
                Rant::TestUtil.in_local_temp_dir do
                    script_fn = opts[:fn] || "fl.rb"
                    dirs = (opts[:dirs] || []).dup
                    touch = (opts[:touch] || []).dup
                    touch.each { |fn| dirs << File.dirname(fn) }
                    dirs.each { |dir|
                        next if [".", "..", "/"].include?(dir)
                        Rant::Sys.mkdir_p dir
                    }
                    touch.each { |fn| Rant::Sys.touch fn }
                    Rant::Sys.write_to_file script_fn, script
                    if opts[:return] == :stdout
                        out = `#{Rant::Sys.sp Rant::Env::RUBY_EXE} -w -I#{Rant::Sys.sp ENV['RANT_DEV_LIB_DIR']} #{Rant::Sys.sp script_fn}`
                    else
                        Rant::Sys.ruby "-w", "-I", ENV["RANT_DEV_LIB_DIR"], script_fn
                    end
                    assert_exit(0, opts[:msg])
                end
                out
            end
	    def assert_rant(*args)
		res = 0
		capture = true
                newproc = false
                tmax_1 = false
                out, err = nil, nil
		args.flatten!
		args.reject! { |arg|
		    if Symbol === arg
			case arg
			when :fail then res = 1
			when :v then capture = false
			when :verbose then capture = false
                        when :x then newproc = true
                        when :tmax_1 then tmax_1 = true
			else
			    raise "No such option -- #{arg}"
			end
			true
		    else
			false
		    end
		}
                action = lambda {
                    if newproc
                        if capture
                            # TODO: stderr
                            out = `#{Rant::Sys.sp(Rant::Env::RUBY_EXE)} #{Rant::Sys.sp(RANT_BIN)} #{args.flatten.join(' ')}`
                        else
                            system("#{Rant::Sys.sp(Rant::Env::RUBY_EXE)} " +
                                "#{Rant::Sys.sp(RANT_BIN)} " +
                                "#{args.flatten.join(' ')}")
                        end
                        assert_equal(res, $?.exitstatus)
                    elsif capture
                        out, err = capture_std do
                            assert_equal(res, ::Rant::RantApp.new.run(*args))
                        end
                    else
                        assert_equal(res, ::Rant::RantApp.new.run(*args))
                    end
                }
                if tmax_1
                    th = Thread.new(&action)
                    unless th.join(1)
                        th.kill
                        assert(false,
                            "execution aborted after 1 second")
                    end
                else
                    action.call
                end
                return out, err
	    end
            def assert_exit(status = 0, msg = nil)
                msg ||= "exit status expected to be " +
                    "#{status} but is #{$?.exitstatus}"
                assert_equal(status, $?.exitstatus, msg)
            end
            def assert_file_content(fn, content, *opts)
                assert(test(?f, fn), "`#{fn}' doesn't exist")
                fc = File.read(fn)
                fc.strip! if opts.include? :strip
                assert(fc == content,
                    "file `#{fn}' should contain `#{content}' " +
                    "but contains `#{fc}'")
            end
            if RUBY_VERSION < "1.8.1"
                def assert_raise(*args, &block)
                    assert_raises(*args, &block)
                end
            end
            def assert_raise_kind_of(klass)
                e = nil
                begin
                    yield
                rescue Exception => e
                end
                if e.nil?
                    flunk("Exception `#{klass}' expected but non risen.")
                else
                    unless e.kind_of? klass
                        flunk("Exception `#{klass}' expected " +
                            "but `#{e.class}' thrown")
                    end
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

def _sleep
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
    `#{Rant::Sys.sp(Rant::Env::RUBY_EXE)} #{Rant::Sys.sp(RANT_BIN)} #{args.flatten.join(' ')}`
end

def run_import(*args)
    `#{Rant::Sys.sp(Rant::Env::RUBY_EXE)} #{Rant::Sys.sp(RANT_IMPORT_BIN)} #{args.flatten.join(' ')}`
end

def run_ruby(*args)
    `#{Rant::Sys.sp(Rant::Env::RUBY_EXE)} #{args.flatten.join(' ')}`
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
    TEST_HARDLINK_BROKEN = Rant::Env.on_windows? && RUBY_VERSION < "1.8.4"
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
    # replacement for core <tt>test(?-, a, b)</tt> which is eventually
    # corrupted
    if TEST_HARDLINK_BROKEN
        def test_hardlink(a, b, opts = {})
            # test(?-, a, b) corrupt in ruby < 1.8.4 (final)
            # on Windows
            
            unless defined? @@corrupt_test_hardlink_msg
                @@corrupt_test_hardlink_msg = true
                puts "\n*** Ruby core test for hardlinks " +
                    "[test(?-, file1, file2)] considered broken. Using heuristics for unit tests. ***"
            end

            # Use some heuristic instead.
            if test(?l, a)
                return test(?l, b) &&
                    File.readlink(a) == File.readlink(b)
            else
                return false if test(?l, b)
            end
            content = File.read(a)
            return false unless File.read(b) == content
            if opts[:allow_write]
                if content.size > 1
                    Rant::TestUtil.write_to_file(a, content[0])
                else
                    Rant::TestUtil.write_to_file(a, "hardlink test\n")
                end
                File.read(a) == File.read(b)
            else
                true
            end
        end
    else
        def test_hardlink(a, b, opts = {})
            test(?-, a, b)
        end
    end
    extend self
end
