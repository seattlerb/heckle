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
  undef_method :default_test
  def setup
    @nodes ||= Heckle::MUTATABLE_NODES
    data = self.class.name["TestHeckle".size..-1].gsub(/([A-Z])/, '_\1').downcase
    data = "_many_things" if data.empty?
    @heckler = TestHeckler.new("Heckled", "uses#{data}", @nodes)
  end

  def teardown
    @heckler.reset
  end
end

class LiteralHeckleTestCase < HeckleTestCase
  def setup
    @nodes = [:lit, :str]
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
    expected = [:defn, :uses_many_things,
                [:fbody,
                 [:scope,
                  [:block,
                   [:args],
                   [:lasgn, :i, [:lit, 1]],
                   [:while,
                    [:call, [:lvar, :i], :<, [:array, [:lit, 10]]],
                    [:block,
                     [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 1]]]],
                     [:until, [:vcall, :some_func],
                      [:vcall, :some_other_func], true],
                     [:if,
                      [:call, [:str, "hi there"], :==,
                       [:array, [:str, "changeling"]]],
                      [:return, [:true]],
                      nil],
                     [:return, [:false]]],
                    true],
                   [:lvar, :i]]]]]

    assert_equal expected, @heckler.original_tree
  end

  def test_should_grab_mutatees_from_method
    # expected is from tree of uses_while
    expected = {
      :call => [[:call, [:lvar, :i], :<, [:array, [:lit, 10]]],
                [:call, [:lvar, :i], :+, [:array, [:lit, 1]]],
                [:call, [:str, "hi there"], :==,
                        [:array, [:str, "changeling"]]]],
      :cvasgn => [], # no cvasgns here
      :dasgn => [], # no dasgns here
      :dasgn_curr => [], # no dasgn_currs here
      :iasgn => [], # no iasgns here
      :gasgn => [], # no gasgns here
      :lasgn => [[:lasgn, :i, [:lit, 1]],
                 [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 1]]]]],
      :lit => [[:lit, 1], [:lit, 10], [:lit, 1]],
      :if => [[:if,
               [:call, [:str, "hi there"], :==, [:array, [:str, "changeling"]]],
               [:return, [:true]],
               nil]],
      :str => [[:str, "hi there"], [:str, "changeling"]],
      :true => [[:true]],
      :false => [[:false]],
      :while => [[:while,
                  [:call, [:lvar, :i], :<, [:array, [:lit, 10]]],
                  [:block,
                   [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 1]]]],
                   [:until, [:vcall, :some_func],
                    [:vcall, :some_other_func], true],
                   [:if,
                    [:call, [:str, "hi there"], :==,
                     [:array, [:str, "changeling"]]],
                    [:return, [:true]],
                    nil],
                   [:return, [:false]]],
                  true]],
      :until => [[:until, [:vcall, :some_func], [:vcall, :some_other_func], true]]
    }

    assert_equal expected, @heckler.mutatees
  end

  def test_should_count_mutatees_left
    assert_equal 15, @heckler.mutations_left
  end

  def test_reset
    original_tree = @heckler.current_tree.deep_clone
    original_mutatees = @heckler.mutatees.deep_clone

    3.times { @heckler.process(@heckler.current_tree) }

    assert_not_equal original_tree, @heckler.current_tree
    assert_not_equal original_mutatees, @heckler.mutatees

    @heckler.reset
    assert_equal original_tree[2], @heckler.current_tree[2][1]
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
    [:defn, :uses_numeric_literals,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, toggle(1, 1 == n)]],
       [:lasgn, :i, [:call, [:lvar, :i], :+,
                     [:array, [:lit, toggle(2147483648, 2 == n)]]]],
       [:lasgn, :i, [:call, [:lvar, :i], :-, [:array, [:lit, toggle(3.5, 3 == n)]]]]]]]
  end
end

class TestHeckleSymbols < LiteralHeckleTestCase
  TOGGLE_VALUE = :"l33t h4x0r"

  def util_expected(n = nil)
    [:defn, :uses_symbols,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, toggle(:blah, n == 1)]],
       [:lasgn, :i, [:lit, toggle(:blah, n == 2)]],
       [:lasgn, :i, [:lit, toggle(:and_blah, n == 3)]]]]]
  end
end

class TestHeckleRegexes < LiteralHeckleTestCase
  TOGGLE_VALUE = /l33t\ h4x0r/

  def util_expected(n = nil)
    [:defn, :uses_regexes,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, toggle(/a.*/, n == 1)]],
       [:lasgn, :i, [:lit, toggle(/c{2,4}+/, n == 2)]],
       [:lasgn, :i, [:lit, toggle(/123/, n == 3)]]]]]
  end
end

class TestHeckleRanges < LiteralHeckleTestCase
  TOGGLE_VALUE = 5..10

  def util_expected(n = nil)
    [:defn, :uses_ranges,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, toggle(6..100, n == 1)]],
       [:lasgn, :i, [:lit, toggle(-1..9, n == 2)]],
       [:lasgn, :i, [:lit, toggle(1..4, n == 3)]]]]]
  end
end

class TestHeckleSameLiteral < LiteralHeckleTestCase
  TOGGLE_VALUE = 6

  def util_expected(n = nil)
    [:defn, :uses_same_literal,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, toggle(1, n == 1)]],
       [:lasgn, :i, [:lit, toggle(1, n == 2)]],
       [:lasgn, :i, [:lit, toggle(1, n == 3)]]]]]
  end
end

class TestHeckleStrings < LiteralHeckleTestCase
  TOGGLE_VALUE = "l33t h4x0r"

  def util_expected(n = nil)
    [:defn, :uses_strings,
     [:scope,
      [:block,
       [:args],
       [:call, [:ivar, :@names], :<<, [:array, [:str, toggle("Hello, Robert", n == 1)]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, toggle("Hello, Jeff", n == 2)]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, toggle("Hi, Frank", n == 3)]]]]]]
  end
end

class TestHeckleIf < HeckleTestCase
  def test_default_structure
    expected = [:defn, :uses_if,
                [:scope,
                 [:block,
                  [:args],
                  [:if,
                   [:vcall, :some_func],
                   [:if, [:vcall, :some_other_func], [:return], nil],
                   nil]]]]

    assert_equal expected, @heckler.current_tree
  end

  def test_should_flip_if_to_unless
    expected = [:defn, :uses_if,
                [:scope,
                 [:block,
                  [:args],
                  [:if,
                   [:vcall, :some_func],
                   [:if, [:vcall, :some_other_func], nil, [:return]],
                   nil]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree

    @heckler.reset_tree

    expected = [:defn, :uses_if,
                [:scope,
                 [:block,
                  [:args],
                  [:if,
                   [:vcall, :some_func],
                   nil,
                   [:if, [:vcall, :some_other_func], [:return], nil]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleBoolean < HeckleTestCase

  def setup
    @nodes = [:true, :false]
    super
  end

  def toggle(value, toggle)
    (toggle ? ! value : value).to_s.intern
  end

  def util_expected(n = nil)
    [:defn, :uses_boolean,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :a, [toggle(true, n == 1)]],
       [:lasgn, :b, [toggle(false, n == 2)]]]]]
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
  def test_default_structure
    expected = [:defn, :uses_while,
                [:scope,
                 [:block,
                  [:args],
                  [:while, [:vcall, :some_func],
                   [:vcall, :some_other_func], true]]]]
    assert_equal expected, @heckler.current_tree
  end

  def test_flips_while_to_until
    expected = [:defn, :uses_while,
                [:scope,
                 [:block,
                  [:args],
                  [:until, [:vcall, :some_func],
                   [:vcall, :some_other_func], true]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleUntil < HeckleTestCase
  def test_default_structure
    expected = [:defn, :uses_until,
                [:scope,
                 [:block,
                  [:args],
                  [:until, [:vcall, :some_func],
                   [:vcall, :some_other_func], true]]]]
    assert_equal expected, @heckler.current_tree
  end

  def test_flips_until_to_while
    expected = [:defn, :uses_until,
                [:scope,
                 [:block,
                  [:args],
                  [:while, [:vcall, :some_func],
                   [:vcall, :some_other_func], true]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleCall < HeckleTestCase

  def test_call_deleted
    expected = [:defn, :uses_call,
                [:scope,
                 [:block,
                  [:args],
                  [:nil]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_default_structure
    expected = [:defn, :uses_call,
                [:fbody,
                 [:scope,
                  [:block,
                   [:args],
                   [:call,
                    [:vcall, :some_func],
                    :+,
                    [:array, [:vcall, :some_other_func]]]]]]]

    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleCallblock < HeckleTestCase

  def setup
    @nodes = [:call]
    super
  end

  def test_callblock_deleted
    expected = [:defn, :uses_callblock,
                [:scope,
                 [:block,
                  [:args],
                  [:iter, [:call, [:vcall, :x], :y], nil, [:lit, 1]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleClassMethod < Test::Unit::TestCase
  def setup
    @heckler = TestHeckler.new("Heckled", "self.is_a_klass_method?")
  end
  
  def teardown
    @heckler.reset
  end
  
  def test_default_structure
    expected = [:defn, :"self.is_a_klass_method?",
                [:scope,
                 [:block,
                  [:args],
                  [:true]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  def test_heckle_class_methods
    expected = [:defn, :"self.is_a_klass_method?",
                [:scope,
                 [:block,
                  [:args],
                  [:false]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleCvasgn < HeckleTestCase

  def setup
    @nodes = [:cvasgn]
    super
  end

  def test_cvasgn_val
    expected = [:defn, :uses_cvasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:cvasgn, :@@cvar, [:nil]],
                  [:cvasgn, :@@cvar, [:nil]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_cvasgn_nil
    expected = [:defn, :uses_cvasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:cvasgn, :@@cvar, [:lit, 5]],
                  [:cvasgn, :@@cvar, [:lit, 42]]]]]

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleDasgn < HeckleTestCase

  def setup
    @nodes = [:dasgn]
    super
  end

  def test_dasgn_val
    expected = [:defn, :uses_dasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:iter,
                    [:fcall, :loop],
                    [:dasgn_curr, :dvar],
                    [:iter,
                      [:fcall, :loop],
                      nil,
                      [:block,
                        [:dasgn, :dvar, [:nil]],
                        [:dasgn, :dvar, [:nil]]]]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_dasgn_nil
    expected = [:defn, :uses_dasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:iter,
                    [:fcall, :loop],
                    [:dasgn_curr, :dvar],
                    [:iter,
                      [:fcall, :loop],
                      nil,
                      [:block,
                        [:dasgn, :dvar, [:lit, 5]],
                        [:dasgn, :dvar, [:lit, 42]]]]]]]]

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleDasgncurr < HeckleTestCase

  def setup
    @nodes = [:dasgn_curr]
    super
  end

  def test_dasgn_curr_val
    expected = [:defn, :uses_dasgncurr,
                [:scope,
                 [:block,
                  [:args],
                  [:iter,
                    [:fcall, :loop],
                    [:dasgn_curr, :dvar],
                    [:block,
                      [:dasgn_curr, :dvar, [:nil]],
                      [:dasgn_curr, :dvar, [:nil]]]]]]]

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_dasgn_curr_nil
    expected = [:defn, :uses_dasgncurr,
                [:scope,
                 [:block,
                  [:args],
                  [:iter,
                    [:fcall, :loop],
                    [:dasgn_curr, :dvar],
                    [:block,
                      [:dasgn_curr, :dvar, [:lit, 5]],
                      [:dasgn_curr, :dvar, [:lit, 42]]]]]]]

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleIasgn < HeckleTestCase

  def setup
    @nodes = [:iasgn]
    super
  end

  def test_iasgn_val
    expected = [:defn, :uses_iasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:iasgn, :@ivar, [:nil]],
                  [:iasgn, :@ivar, [:nil]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_iasgn_nil
    expected = [:defn, :uses_iasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:iasgn, :@ivar, [:lit, 5]],
                  [:iasgn, :@ivar, [:lit, 42]]]]]

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleGasgn < HeckleTestCase

  def setup
    @nodes = [:gasgn]
    super
  end

  def test_gasgn_val
    expected = [:defn, :uses_gasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:gasgn, :$gvar, [:nil]],
                  [:gasgn, :$gvar, [:nil]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_gasgn_nil
    expected = [:defn, :uses_gasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:gasgn, :$gvar, [:lit, 5]],
                  [:gasgn, :$gvar, [:lit, 42]]]]]

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleLasgn < HeckleTestCase

  def setup
    @nodes = [:lasgn]
    super
  end

  def test_lasgn_val
    expected = [:defn, :uses_lasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:lasgn, :lvar, [:nil]],
                  [:lasgn, :lvar, [:nil]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

  def test_lasgn_nil
    expected = [:defn, :uses_lasgn,
                [:scope,
                 [:block,
                  [:args],
                  [:lasgn, :lvar, [:lit, 5]],
                  [:lasgn, :lvar, [:lit, 42]]]]]

    @heckler.process(@heckler.current_tree)
    @heckler.reset_tree
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

class TestHeckleMasgn < HeckleTestCase

  def setup
    @nodes = [:dasgn, :dasgn_curr, :iasgn, :gasgn, :lasgn]
    super
  end

  def test_masgn
    expected = [:defn, :uses_masgn,
                [:scope,
                 [:block,
                  [:args],
                  [:masgn,
                    [:array,
                      [:lasgn, :_heckle_dummy],
                      [:gasgn, :$b],
                      [:lasgn, :c]],
                    [:array, [:lit, 5], [:lit, 6], [:lit, 7]]]]]]

    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end

end

