
require 'test/unit'
require 'rant/rantlib'
require 'tutil'

$testPluginConfCsDir = File.expand_path(File.dirname(__FILE__))
$have_csc ||= Rant::Env.find_bin("csc") ||
    Rant::Env.find_bin("cscc") || Rant::Env.find_bin("mcs")

class TestConfCsharp < Test::Unit::TestCase
    def setup
	# Ensure we run in test directory.
	Dir.chdir($testPluginConfCsDir) unless Dir.pwd == $testPluginConfCsDir
    end
    def teardown
	capture_std do
	    assert_equal(0, Rant.run("clean"))
	end
    end
if $have_csc
    def test_defaults
	capture_std do
	    assert_equal(0, Rant.run([]))
	end
	assert(test(?f, "conf_csharp.cs"),
	    "conf_csharp.cs should be created by default task")
	assert(test(?f, "conf_csharp.exe"),
	    "conf_csharp.exe should be compiled by default task")
	assert(test(?f, "config"),
	    "config should habe been created by Configure plugin")
    end
    def test_with_explicit_target
	capture_std do
	    assert_equal(0, Rant.run(%w(target=myprog.exe)))
	end
	assert(test(?f, "conf_csharp.cs"))
	assert(test(?f, "myprog.exe"),
	    "myprog.exe was given as target name on commandline")
	assert(test(?f, "config"))
	File.delete "myprog.exe"
	capture_std do
	    assert_equal(0, Rant.run([]))
	end
	assert(test(?f, "myprog.exe"),
	    "target should be set to myprog.exe from config")
    end
end
end
