
module WGrep

    class CommandError < StandardError
    end

    class WGrep
	attr_reader :word
	attr_reader :files
	attr_reader :count
	def initialize
	    @word = nil
	    @files = []
	    @count = 0
	end

	def run(args = ARGV)
	    process_args args
	    @count = 0
	    if @files.empty?
		self.grep(@word, $stdin) { |line|
		    print line
		    @count += 1
		}
	    else
		@files.each { |fn|
		    File.open(fn) { |file|
			self.grep(@word, file) { |line|
			    print line
			    @count += 1
			}
		    }
		}
	    end
	    $stderr.puts "Found `#@word' in #{@count} lines."
	    0
	rescue CommandError => e
	    $stderr.puts "Invalid commandline: #{e.message}"
	    1
	end

	def process_args(args)
	    if args.nil? || args.empty?
		raise CommandError, "No word given."
	    end
	    args = [args] unless Array === args
	    @word, @files = args[0], args[1..-1]
	end

	def grep(word, stream)
	    stream.each { |rec|
		yield(rec) if rec =~ /\b#{Regexp.escape(word)}\b/
	    }
	end
    end
end
