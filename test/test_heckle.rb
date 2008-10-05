$:.unshift(File.dirname(__FILE__) + '/fixtures')
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit/testcase'
require 'test/unit' if $0 == __FILE__
require 'test_unit_heckler'
require 'heckled'

class TestHeckler < Heckle
  def rand(*args)
    5
  end

  def rand_string
    "l33t h4x0r"
  end

  def rand_number(*args)
    5
  end

  def rand_symbol
    :"l33t h4x0r"
  end
end

class HeckleTestCase < Test::Unit::TestCase
  undef_method :default_test unless defined? Mini

  def setup
    @nodes ||= Heckle::MUTATABLE_NODES
    unless defined? @name then
      data = self.class.name["TestHeckle".size..-1]
      data = data.gsub(/([A-Z])/, '_\1').downcase
      data = "_many_things" if data.empty?
      @name = "uses#{data}"
    end
    @heckler = TestHeckler.new("Heckled", @name, @nodes)
  end

  def teardown
    @heckler.reset if defined? @heckler
  end
end

class LiteralHeckleTestCase < HeckleTestCase
  def setup
    @nodes = s(:lit, :str)
    super
  end

  def toggle(value, toggle)
    toggle ? self.class::TOGGLE_VALUE : value
  end

  def test_default_structure
    return if self.class == LiteralHeckleTestCase
    assert_equal util_expected, @heckler.current_tree
  end

  def test_should_iterate_mutations
    return if self.class == LiteralHeckleTestCase
    @heckler.process(@heckler.current_tree)
    assert_equal util_expected(1), @heckler.current_tree

    @heckler.reset_tree

    @heckler.process(@heckler.current_tree)
    assert_equal util_expected(2), @heckler.current_tree

    @heckler.reset_tree

    @heckler.process(@heckler.current_tree)
    assert_equal util_expected(3), @heckler.current_tree
  end
end

class TestHeckle < HeckleTestCase
  def test_should_set_original_tree
    expected = s(:defn, :uses_many_things,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:lasgn, :i, s(:lit, 1)),
                     s(:while,
                       s(:call, s(:lvar, :i), :<, s(:arglist, s(:lit, 10))),
                       s(:block,
                         s(:lasgn, :i, s(:call, s(:lvar, :i), :+, s(:arglist, s(:lit, 1)))),
                         s(:until, s(:call, nil, :some_func, s(:arglist)),
                           s(:call, nil, :some_other_func, s(:arglist)), true),
                         s(:if,
                           s(:call, s(:str, "hi there"), :==,
                             s(:arglist, s(:str, "changeling"))),
                           s(:return, s(:true)),
                           nil),
                         s(:return, s(:false))),
                       true),
                     s(:lvar, :i))))

    assert_equal expected, @heckler.original_tree
  end

  def test_should_grab_mutatees_from_method
    # expected is from tree of uses_while
    expected = {
      :call => [s(:call, s(:lvar, :i), :<, s(:arglist, s(:lit, 10))),
                s(:call, s(:lvar, :i), :+, s(:arglist, s(:lit, 1))),
                s(:call, nil, :some_func, s(:arglist)), # FIX: why added?
                s(:call, nil, :some_other_func, s(:arglist)), # FIX: why added?
                s(:call, s(:str, "hi there"), :==,
                  s(:arglist, s(:str, "changeling")))],
      :cvasgn => [],     # no cvasgns here
      :dasgn => [],      # no dasgns here
      :dasgn_curr => [], # no dasgn_currs here
      :iasgn => [],      # no iasgns here
      :iter => [],
      :gasgn => [],      # no gasgns here
      :lasgn => [s(:lasgn, :i, s(:lit, 1)),
                 s(:lasgn, :i, s(:call, s(:lvar, :i), :+, s(:arglist, s(:lit, 1))))],
      :lit => [s(:lit, 1), s(:lit, 10), s(:lit, 1)],
      :if => [s(:if,
                s(:call, s(:str, "hi there"), :==, s(:arglist, s(:str, "changeling"))),
                s(:return, s(:true)),
                nil)],
      :str => [s(:str, "hi there"), s(:str, "changeling")],
      :true => [s(:true)],
      :false => [s(:false)],
      :while => [s(:while,
                   s(:call, s(:lvar, :i), :<, s(:arglist, s(:lit, 10))),
                   s(:block,
                     s(:lasgn, :i, s(:call, s(:lvar, :i), :+, s(:arglist, s(:lit, 1)))),
                     s(:until, s(:call, nil, :some_func, s(:arglist)),
                       s(:call, nil, :some_other_func, s(:arglist)), true),
                     s(:if,
                       s(:call, s(:str, "hi there"), :==,
                         s(:arglist, s(:str, "changeling"))),
                       s(:return, s(:true)),
                       nil),
                     s(:return, s(:false))),
                   true)],
      :until => [s(:until,
                   s(:call, nil, :some_func, s(:arglist)),
                   s(:call, nil, :some_other_func, s(:arglist)),
                   true)],
    }

    assert_equal expected, @heckler.mutatees
  end

  def test_should_count_mutatees_left
    assert_equal 17, @heckler.mutations_left # FIX WHY?!?
  end

  def test_reset
    original_tree = @heckler.current_tree.deep_clone
    original_mutatees = @heckler.mutatees.deep_clone

    3.times { @heckler.process(@heckler.current_tree) }

    assert_not_equal original_tree, @heckler.current_tree
    assert_not_equal original_mutatees, @heckler.mutatees

    @heckler.reset
    assert_equal original_tree[2], @heckler.current_tree[2]
    assert_equal original_mutatees, @heckler.mutatees
  end

  def test_reset_tree
    original_tree = @heckler.current_tree.deep_clone

    @heckler.process(@heckler.current_tree)
    assert_not_equal original_tree, @heckler.current_tree

    @heckler.reset_tree
    assert_equal original_tree, @heckler.current_tree
  end

  def test_reset_should_work_over_several_process_calls
    original_tree = @heckler.current_tree.deep_clone
    original_mutatees = @heckler.mutatees.deep_clone

    @heckler.process(@heckler.current_tree)
    assert_not_equal original_tree, @heckler.current_tree
    assert_not_equal original_mutatees, @heckler.mutatees

    @heckler.reset
    assert_equal original_tree, @heckler.current_tree
    assert_equal original_mutatees, @heckler.mutatees

    3.times { @heckler.process(@heckler.current_tree) }
    assert_not_equal original_tree, @heckler.current_tree
    assert_not_equal original_mutatees, @heckler.mutatees

    @heckler.reset
    assert_equal original_tree, @heckler.current_tree
    assert_equal original_mutatees, @heckler.mutatees
  end

  def test_reset_mutatees
    original_mutatees = @heckler.mutatees.deep_clone

    @heckler.process(@heckler.current_tree)
    assert_not_equal original_mutatees, @heckler.mutatees

    @heckler.reset_mutatees
    assert_equal original_mutatees, @heckler.mutatees
  end
end

class TestHeckleNumericLiterals < HeckleTestCase
  def toggle(value, toggle)
    value + (toggle ? 5 : 0)
  end

  def util_expected(n)
    s(:defn, :uses_numeric_literals,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, toggle(1, 1 == n))),
          s(:lasgn, :i, s(:call, s(:lvar, :i), :+,
                          s(:arglist, s(:lit, toggle(2147483648, 2 == n))))),
          s(:lasgn, :i, s(:call, s(:lvar, :i), :-, s(:arglist, s(:lit, toggle(3.5, 3 == n))))))))
  end
end

class TestHeckleSymbols < LiteralHeckleTestCase
  TOGGLE_VALUE = :"l33t h4x0r"

  def util_expected(n = nil)
    s(:defn, :uses_symbols,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, toggle(:blah, n == 1))),
          s(:lasgn, :i, s(:lit, toggle(:blah, n == 2))),
          s(:lasgn, :i, s(:lit, toggle(:and_blah, n == 3))))))
  end
end

class TestHeckleRegexes < LiteralHeckleTestCase
  TOGGLE_VALUE = /l33t\ h4x0r/

  def util_expected(n = nil)
    s(:defn, :uses_regexes,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, toggle(/a.*/, n == 1))),
          s(:lasgn, :i, s(:lit, toggle(/c{2,4}+/, n == 2))),
          s(:lasgn, :i, s(:lit, toggle(/123/, n == 3))))))
  end
end

class TestHeckleRanges < LiteralHeckleTestCase
  TOGGLE_VALUE = 5..10

  def util_expected(n = nil)
    s(:defn, :uses_ranges,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, toggle(6..100, n == 1))),
          s(:lasgn, :i, s(:lit, toggle(-1..9, n == 2))),
          s(:lasgn, :i, s(:lit, toggle(1..4, n == 3))))))
  end
end

class TestHeckleSameLiteral < LiteralHeckleTestCase
  TOGGLE_VALUE = 6

  def util_expected(n = nil)
    s(:defn, :uses_same_literal,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, toggle(1, n == 1))),
          s(:lasgn, :i, s(:lit, toggle(1, n == 2))),
          s(:lasgn, :i, s(:lit, toggle(1, n == 3))))))
  end
end

class TestHeckleStrings < LiteralHeckleTestCase
  TOGGLE_VALUE = "l33t h4x0r"

  def util_expected(n = nil)
    s(:defn, :uses_strings,
      s(:args),
      s(:scope,
        s(:block,
          s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, toggle("Hello, Robert", n == 1)))),
          s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, toggle("Hello, Jeff", n == 2)))),
          s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, toggle("Hi, Frank", n == 3)))))))
  end
end

class TestHeckleIf < HeckleTestCase
  def setup
    @nodes = s(:if)
    super
  end

  def test_default_structure
    expected = s(:defn, :uses_if,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:if,
                       s(:call, nil, :some_func, s(:arglist)),
                       s(:if, s(:call, nil, :some_other_func, s(:arglist)), s(:return), nil),
                       nil))))

    assert_equal expected, @heckler.current_tree
  end

  def test_should_flip_if_to_unless
    expected = s(:defn, :uses_if,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:if,
                       s(:call, nil, :some_func, s(:arglist)),
                       s(:if, s(:call, nil, :some_other_func, s(:arglist)), nil, s(:return)),
                       nil))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree

    @heckler.reset_tree

    expected = s(:defn, :uses_if,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:if,
                       s(:call, nil, :some_func, s(:arglist)),
                       nil,
                       s(:if, s(:call, nil, :some_other_func, s(:arglist)), s(:return), nil)))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleBoolean < HeckleTestCase

  def setup
    @nodes = s(:true, :false)
    super
  end

  def toggle(value, toggle)
    (toggle ? ! value : value).to_s.intern
  end

  def util_expected(n = nil)
    s(:defn, :uses_boolean,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :a, s(toggle(true, n == 1))),
          s(:lasgn, :b, s(toggle(false, n == 2))))))
  end

  def test_default_structure
    assert_equal util_expected, @heckler.current_tree
  end

  def test_should_flip_true_to_false_and_false_to_true
    @heckler.process(@heckler.current_tree)
    assert_equal util_expected(1), @heckler.current_tree

    @heckler.reset_tree

    @heckler.process(@heckler.current_tree)
    assert_equal util_expected(2), @heckler.current_tree
  end
end

class TestHeckleWhile < HeckleTestCase
  def setup
    @nodes = s(:while)
    super
  end

  def test_default_structure
    expected = s(:defn, :uses_while,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:while, s(:call, nil, :some_func, s(:arglist)),
                       s(:call, nil, :some_other_func, s(:arglist)), true))))
    assert_equal expected, @heckler.current_tree
  end

  def test_flips_while_to_until
    expected = s(:defn, :uses_while,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:until, s(:call, nil, :some_func, s(:arglist)),
                       s(:call, nil, :some_other_func, s(:arglist)), true))))
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleUntil < HeckleTestCase
  def setup
    @nodes = s(:until)
    super
  end

  def test_default_structure
    expected = s(:defn, :uses_until,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:until, s(:call, nil, :some_func, s(:arglist)),
                       s(:call, nil, :some_other_func, s(:arglist)), true))))
    assert_equal expected, @heckler.current_tree
  end

  def test_flips_until_to_while
    expected = s(:defn, :uses_until,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:while, s(:call, nil, :some_func, s(:arglist)),
                       s(:call, nil, :some_other_func, s(:arglist)), true))))
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleCall < HeckleTestCase

  def test_call_deleted
    expected = s(:defn, :uses_call,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:nil))))

    @heckler.process(@heckler.current_tree) # some_func
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree) # some_other_func
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree) # +
    assert_equal expected, @heckler.current_tree
  end

  def test_default_structure
    expected = s(:defn, :uses_call,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:call,
                       s(:call, nil, :some_func, s(:arglist)),
                       :+,
                       s(:arglist, s(:call, nil, :some_other_func, s(:arglist)))))))

    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleCallblock < HeckleTestCase

  def setup
    @nodes = s(:call)
    super
  end

  def test_default_structure
    expected = s(:defn, :uses_callblock,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:iter,
                       s(:call, s(:call, nil, :x, s(:arglist)), :y, s(:arglist)),
                       nil,
                       s(:lit, 1)))))

    assert_equal expected, @heckler.current_tree
  end
  def test_callblock_deleted
    expected = s(:defn, :uses_callblock,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:iter,
                       s(:call, s(:nil), :y, s(:arglist)),
                       nil,
                       s(:lit, 1)))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleClassMethod < HeckleTestCase
  def setup
    @name = "self.is_a_klass_method?"
    @nodes = s(:true)
    super
  end

  def test_default_structure
    expected = s(:defs, s(:self), :is_a_klass_method?,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:true))))
    assert_equal expected, @heckler.current_tree
  end

  def test_heckle_class_methods
    expected = s(:defs, s(:self), :is_a_klass_method?,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:false))))
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleCvasgn < HeckleTestCase

  def setup
    @nodes = s(:cvasgn)
    super
  end

  def test_cvasgn_val
    expected = s(:defn, :uses_cvasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:cvasgn, :@@cvar, s(:nil)),
                     s(:cvasgn, :@@cvar, s(:nil)))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_cvasgn_nil
    expected = s(:defn, :uses_cvasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:cvasgn, :@@cvar, s(:lit, 5)),
                     s(:cvasgn, :@@cvar, s(:lit, 42)))))

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleIasgn < HeckleTestCase

  def setup
    @nodes = s(:iasgn)
    super
  end

  def test_iasgn_val
    expected = s(:defn, :uses_iasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:iasgn, :@ivar, s(:nil)),
                     s(:iasgn, :@ivar, s(:nil)))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_iasgn_nil
    expected = s(:defn, :uses_iasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:iasgn, :@ivar, s(:lit, 5)),
                     s(:iasgn, :@ivar, s(:lit, 42)))))

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleGasgn < HeckleTestCase

  def setup
    @nodes = s(:gasgn)
    super
  end

  def test_gasgn_val
    expected = s(:defn, :uses_gasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:gasgn, :$gvar, s(:nil)),
                     s(:gasgn, :$gvar, s(:nil)))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_gasgn_nil
    expected = s(:defn, :uses_gasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:gasgn, :$gvar, s(:lit, 5)),
                     s(:gasgn, :$gvar, s(:lit, 42)))))

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleLasgn < HeckleTestCase

  def setup
    @nodes = s(:lasgn)
    super
  end

  def test_lasgn_val
    expected = s(:defn, :uses_lasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:lasgn, :lvar, s(:nil)),
                     s(:lasgn, :lvar, s(:nil)))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_lasgn_nil
    expected = s(:defn, :uses_lasgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:lasgn, :lvar, s(:lit, 5)),
                     s(:lasgn, :lvar, s(:lit, 42)))))

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleMasgn < HeckleTestCase

  def setup
    @nodes = s(:dasgn, :dasgn_curr, :iasgn, :gasgn, :lasgn)
    super
  end

  def test_masgn
    expected = s(:defn, :uses_masgn,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:masgn,
                       s(:array,
                         s(:lasgn, :_heckle_dummy),
                         s(:gasgn, :$b),
                         s(:lasgn, :c)),
                       s(:array, s(:lit, 5), s(:lit, 6), s(:lit, 7))))))

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleIter < HeckleTestCase
  def setup
    @nodes = [ :call, :lasgn ]
    super
  end
  
  def test_iter
    expected = s(:defn, :uses_iter,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:lasgn, :x, s(:nil)),
                     s(:iter,
                       s(:call, s(:lvar, :x), :each, s(:arglist)),
                       s(:lasgn, :y),
                       s(:lvar, :y)))))
    
    # This call causes the replacement of [:lasgn, :x...] above to
    # become [:lasgn, :nil].  We then reset the tree to ensure that
    # the original method is maintained.  We are really trying to test
    # the reset_tree method here, not the actual changes.

    @heckler.process(@heckler.current_tree)
    assert_equal(expected, @heckler.current_tree)

    @heckler.reset_tree
    expected = s(:defn, :uses_iter,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:lasgn, :x, s(:array, s(:lit, 1), s(:lit, 2), s(:lit, 3))),
                     s(:iter,
                       s(:call, s(:lvar, :x), :each, s(:arglist)),
                       s(:lasgn, :_heckle_dummy),
                       s(:call, nil, :y, s(:arglist))))))

    @heckler.process(@heckler.current_tree)
    assert_equal(expected, @heckler.current_tree)
  end
end
