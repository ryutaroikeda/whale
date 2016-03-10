require_relative "whale.rb"
require "test/unit"

class TestFilter < Test::Unit::TestCase

  def test_parse_regex
    ts = [ "abc!@#", "(?ix-m:!\/.*[d])" ]
    f = Filter.new
    ts.each do |t|
      e = Regexp.new(t)
      assert_equal f.parse_regex("/#{t}/"), e
    end
  end

end
