
require 'test/unit'
require 'rant'
require 'rant/plugin/csharp'
require 'tutil'

$testPluginCsDir = File.expand_path(File.dirname(__FILE__))
$have_csc ||= Env.find_bin("csc") || Env.find_bin("cscc") || Env.find_bin("mcs")

class TestPluginCsharp < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testPluginCsDir) unless Dir.pwd == $testPluginCsDir
    end
    def teardown
	capture_std do
	    assert(Rant.run("clean"), 0)
	end
	assert(Dir["*.{exe,dll,obj}"].empty?,
	    "task :clean should remove exe, dll and obj files")
    end
if $have_csc
    # Try to compile the "hello world" program. Requires cscc, csc
    # or mcs to be on your PATH.
    def test_hello
	capture_std do
	    assert_equal(Rant.run([]), 0,
		"first target, `hello.exe', should be compiled")
	end
	assert(File.exist?("hello.exe"),
	    "hello.exe is the first target in Rantfile")
	if Env.on_windows?
	    assert_equal(`hello.exe`.chomp, "Hello, world!",
		"hello.exe should print `Hello, world!'")
	elsif (ilrun = Env.find_bin("ilrun"))
	    assert_equal(`#{ilrun} hello.exe`.chomp, "Hello, world!",
		"hello.exe should print `Hello, world!'")
	elsif (mono = Env.find_bin("mono"))
	    assert_equal(`#{mono} hello.exe`.chomp, "Hello, world!",
		"hello.exe should print `Hello, world!'")
	else
	    $stderr.puts "Can't run hello.exe for testing."
	end
    end
    def test_opts
	capture_std do
	    assert_equal(Rant.run("AB.dll"), 0)
	end
	assert(File.exist?("hello.exe"),
	    "AB.dll depends on hello.exe")
	assert(File.exist?("AB.dll"))
    end
    def test_cscc
	old_csc = Assembly.csc
	cscc = Env.find_bin("cscc")
	unless cscc
	    $stderr.puts "cscc not on path, will not test cscc"
	    return
	end
	Assembly.csc = cscc
	test_opts
	Assembly.csc = old_csc
    end
    def test_mcs
	old_csc = Assembly.csc
	mcs = Env.find_bin("mcs")
	unless mcs
	    $stderr.puts "mcs not on path, will not test mcs"
	    return
	end
	Assembly.csc = mcs
	test_opts
	Assembly.csc = old_csc
    end
    def test_csc
	old_csc = Assembly.csc
	csc = Env.find_bin("csc")
	unless csc
	    $stderr.puts "csc not on path, will not test csc"
	    return
	end
	Assembly.csc = csc
	test_opts
	Assembly.csc = old_csc
    end
else
    def test_dummy
	# required to fool test/unit if no C# compiler available,
	# so we skip all real tests
	assert(true)
	# remove this method if a test is added that doesn't depend on
	# the C# compiler
    end
    print <<-EOF
************************************************************
* No C# compiler found on your path. Skipping all tests    *
* depending on a C# compiler.                              *
************************************************************
    EOF
end
end
