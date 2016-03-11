require 'whale'
require "test/unit"

class TestFilter < Test::Unit::TestCase

  def test_parse_filter
    f = Filter.new
    s = '&'
    f.parse_filter s
    assert_equal f.stack.first, :FILTER_AND
  end

end
