
# This file contains methods that aid in testing Rant.

RANT_BIN = File.expand_path(
    File.join(File.dirname(__FILE__), "..", "run_rant"))

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
    `#{Rant::Env::RUBY} #{RANT_BIN} #{args.join(' ')}`
end
