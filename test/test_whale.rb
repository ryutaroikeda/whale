require 'whale'
require 'logger'
require "test/unit"

$logger = Logger.new STDOUT

class TestFilter < Test::Unit::TestCase

  def test_parse_filter
    f = Filter.new
    s = '&'
    f.parse_filter s, $logger
    assert_equal f.stack.first, :FILTER_AND
  end

end
