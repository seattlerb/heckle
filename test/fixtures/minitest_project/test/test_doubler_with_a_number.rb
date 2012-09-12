require "minitest/autorun"
require "doubler"

class TestDoubler < MiniTest::Unit::TestCase
  def setup
    @doubler = Doubler.new
  end

  def test_double_with_a_number
    assert_equal 4, @doubler.double(2)
  end
end
