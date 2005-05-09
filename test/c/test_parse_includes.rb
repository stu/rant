
require 'tutil'
require 'rant/c/include'

$testCDir ||= File.expand_path(File.dirname(__FILE__))

class TestCParseIncludes < Test::Unit::TestCase
    C = Rant::C
    def setup
	Dir.chdir($testCDir)
    end
    def test_parse_source
	src = File.read "source.c"
	sc, lc = C::Include.parse_includes(src)
	assert_equal(%w(stdio.h file.h std), sc)
	assert_equal(
	    %w(util.h mylib.h custom custom2.h), lc)
    end
    def test_parse_empty
	sc, lc = C::Include.parse_includes("")
	assert(sc.empty?)
	assert(lc.empty?)
    end
    def test_parse_nil
	assert_raises(ArgumentError) {
	    C::Include.parse_includes(nil)
	}
    end
    def test_accepts_to_str
	obj = Object.new
	def obj.to_str
	    "//"
	end
	lc, sc = nil, nil
	assert_nothing_raised {
	    sc, lc = C::Include.parse_includes(obj)
	}
	assert(sc.empty?)
	assert(lc.empty?)
    end
end
