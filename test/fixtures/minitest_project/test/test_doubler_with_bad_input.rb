require "minitest/autorun"
require "doubler"

class TestDoublerWithBadInput < MiniTest::Unit::TestCase
  def setup
    @doubler = Doubler.new
  end

  def test_doubler_with_a_string
    assert_equal "NaN", @doubler.double("2")
  end

  def test_doubler_with_nil
    assert_equal "NaN", @doubler.double(nil)
  end
end
