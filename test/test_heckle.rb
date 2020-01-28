require 'fixtures/heckle_dummy'
require 'minitest/unit'
require 'heckle'

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

  # HAX
  def expand_dirs_to_files(*)
    super('test/fixtures/heckle_dummy.rb')
  end
end

class HeckleTestCase < MiniTest::Unit::TestCase
  def setup
    @klass ||= "HeckleDummy"
    @nodes ||= Heckle::MUTATABLE_NODES
    @method_heckled ||= 'uses_many_things'

    @heckler = TestHeckler.new(@klass, @method_heckled, @nodes)
  end

  def teardown
    @heckler.reset if defined?(@heckler) && @heckler
  end

  def assert_mutations expected, heckle
    initial = heckle.current_tree.deep_clone
    mutations = []

    begin
      heckle.process(heckle.current_tree)
      mutant = heckle.current_tree
      mutations << mutant
      heckle.reset_tree
    end until initial == mutant

    mutations.delete(initial)

    # HAX: Sorting an array of Sexps blows up in some cases.
    assert_equal expected.map {|sexp| sexp.to_s }.sort,
      mutations.map {|sexp| sexp.to_s }.sort,
      [ "expected(#{expected.size}):", (expected - mutations).map {|m| m.pretty_inspect},
        "mutations(#{mutations.size}):", (mutations - expected).map {|m| m.pretty_inspect} ].join("\n")
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

    refute_equal original_tree, @heckler.current_tree
    refute_equal original_mutatees, @heckler.mutatees

    @heckler.reset
    assert_equal original_tree[2], @heckler.current_tree[2]
    assert_equal original_mutatees, @heckler.mutatees
  end

  def test_reset_tree
    original_tree = @heckler.current_tree.deep_clone

    @heckler.process(@heckler.current_tree)
    refute_equal original_tree, @heckler.current_tree

    @heckler.reset_tree
    assert_equal original_tree, @heckler.current_tree
  end

  def test_reset_should_work_over_several_process_calls
    original_tree = @heckler.current_tree.deep_clone
    original_mutatees = @heckler.mutatees.deep_clone

    @heckler.process(@heckler.current_tree)
    refute_equal original_tree, @heckler.current_tree
    refute_equal original_mutatees, @heckler.mutatees

    @heckler.reset
    assert_equal original_tree, @heckler.current_tree
    assert_equal original_mutatees, @heckler.mutatees

    3.times { @heckler.process(@heckler.current_tree) }
    refute_equal original_tree, @heckler.current_tree
    refute_equal original_mutatees, @heckler.mutatees

    @heckler.reset
    assert_equal original_tree, @heckler.current_tree
    assert_equal original_mutatees, @heckler.mutatees
  end

  def test_reset_mutatees
    original_mutatees = @heckler.mutatees.deep_clone

    @heckler.process(@heckler.current_tree)
    refute_equal original_mutatees, @heckler.mutatees

    @heckler.reset_mutatees
    assert_equal original_mutatees, @heckler.mutatees
  end
end

class TestHeckleNumericLiterals < HeckleTestCase
  def setup
    @method_heckled = "uses_numeric_literals"
    @nodes = s(:lit, :str)
    super
  end

  def test_numeric_literals_original_tree
    expected = s(:defn, :uses_numeric_literals,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, 1)),
          s(:lasgn, :i, s(:call, s(:lvar, :i), :+,
                          s(:arglist, s(:lit, 2147483648)))),
          s(:lasgn, :i, s(:call, s(:lvar, :i), :-, s(:arglist, s(:lit, 3.5)))))))

    assert_equal expected, @heckler.current_tree
  end

  def test_numeric_literals_mutations
    expected = [
      s(:defn, :uses_numeric_literals,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 6)),
            s(:lasgn, :i, s(:call, s(:lvar, :i), :+,
                            s(:arglist, s(:lit, 2147483648)))),
            s(:lasgn, :i, s(:call, s(:lvar, :i), :-, s(:arglist, s(:lit, 3.5))))))),
      s(:defn, :uses_numeric_literals,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 1)),
            s(:lasgn, :i, s(:call, s(:lvar, :i), :+,
                            s(:arglist, s(:lit, 2147483653)))),
            s(:lasgn, :i, s(:call, s(:lvar, :i), :-, s(:arglist, s(:lit, 3.5))))))),
      s(:defn, :uses_numeric_literals,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 1)),
            s(:lasgn, :i, s(:call, s(:lvar, :i), :+,
                            s(:arglist, s(:lit, 2147483648)))),
            s(:lasgn, :i, s(:call, s(:lvar, :i), :-, s(:arglist, s(:lit, 8.5))))))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleSymbols < HeckleTestCase
  def setup
    @method_heckled = "uses_symbols"
    @nodes = s(:lit, :str)
    super
  end

  def test_symbols_original_tree
    expected = s(:defn, :uses_symbols,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, :blah)),
          s(:lasgn, :i, s(:lit, :blah)),
          s(:lasgn, :i, s(:lit, :and_blah)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_symbols_mutations
    expected = [
      s(:defn, :uses_symbols,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, :"l33t h4x0r")),
            s(:lasgn, :i, s(:lit, :blah)),
            s(:lasgn, :i, s(:lit, :and_blah))))),
      s(:defn, :uses_symbols,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, :blah)),
            s(:lasgn, :i, s(:lit, :"l33t h4x0r")),
            s(:lasgn, :i, s(:lit, :and_blah))))),
      s(:defn, :uses_symbols,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, :blah)),
            s(:lasgn, :i, s(:lit, :blah)),
            s(:lasgn, :i, s(:lit, :"l33t h4x0r"))))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleRegexes < HeckleTestCase
  def setup
    @method_heckled = "uses_regexes"
    @nodes = s(:lit, :str)
    super
  end

  def test_regexes_original_tree
    expected = s(:defn, :uses_regexes,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, /a.*/)),
          s(:lasgn, :i, s(:lit, /c{2,4}+/)),
          s(:lasgn, :i, s(:lit, /123/)))))

    assert_equal expected, @heckler.original_tree
  end

  def test_regexes_mutuations
    expected = [
      s(:defn, :uses_regexes,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, /l33t\ h4x0r/)),
            s(:lasgn, :i, s(:lit, /c{2,4}+/)),
            s(:lasgn, :i, s(:lit, /123/))))),
      s(:defn, :uses_regexes,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, /a.*/)),
            s(:lasgn, :i, s(:lit, /l33t\ h4x0r/)),
            s(:lasgn, :i, s(:lit, /123/))))),
      s(:defn, :uses_regexes,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, /a.*/)),
            s(:lasgn, :i, s(:lit, /c{2,4}+/)),
            s(:lasgn, :i, s(:lit, /l33t\ h4x0r/))))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleRanges < HeckleTestCase
  def setup
    @method_heckled = "uses_ranges"
    @nodes = s(:lit, :str)
    super
  end

  def test_ranges_original_tree
    expected = s(:defn, :uses_ranges,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, 6..100)),
          s(:lasgn, :i, s(:lit, -1..9)),
          s(:lasgn, :i, s(:lit, 1..4)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_ranges_mutations
    expected = [
      s(:defn, :uses_ranges,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 5..10)),
            s(:lasgn, :i, s(:lit, -1..9)),
            s(:lasgn, :i, s(:lit, 1..4))))),
      s(:defn, :uses_ranges,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 6..100)),
            s(:lasgn, :i, s(:lit, 5..10)),
            s(:lasgn, :i, s(:lit, 1..4))))),
      s(:defn, :uses_ranges,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 6..100)),
            s(:lasgn, :i, s(:lit, -1..9)),
            s(:lasgn, :i, s(:lit, 5..10))))),
    ]

    assert_mutations expected, @heckler

  end
end

class TestHeckleSameLiteral < HeckleTestCase
  def setup
    @method_heckled = "uses_same_literal"
    @nodes = s(:lit, :str)
    super
  end

  def test_same_literal_original_tree
    expected = s(:defn, :uses_same_literal,
      s(:args),
      s(:scope,
        s(:block,
          s(:lasgn, :i, s(:lit, 1)),
          s(:lasgn, :i, s(:lit, 1)),
          s(:lasgn, :i, s(:lit, 1)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_same_literal_mutations
    expected = [
      s(:defn, :uses_same_literal,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 6)),
            s(:lasgn, :i, s(:lit, 1)),
            s(:lasgn, :i, s(:lit, 1))))),
      s(:defn, :uses_same_literal,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 1)),
            s(:lasgn, :i, s(:lit, 6)),
            s(:lasgn, :i, s(:lit, 1))))),
      s(:defn, :uses_same_literal,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :i, s(:lit, 1)),
            s(:lasgn, :i, s(:lit, 1)),
            s(:lasgn, :i, s(:lit, 6))))),
      ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleStrings < HeckleTestCase
  def setup
    @method_heckled = "uses_strings"
    @nodes = s(:lit, :str)
    super
  end

  def test_strings_original_tree
    expected = s(:defn, :uses_strings,
      s(:args),
      s(:scope,
        s(:block,
          s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hello, Robert"))),
          s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hello, Jeff"))),
          s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hi, Frank"))))))

    assert_equal expected, @heckler.current_tree
  end

  def test_strings_mutations
    expected = [
      s(:defn, :uses_strings,
        s(:args),
        s(:scope,
          s(:block,
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "l33t h4x0r"))),
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hello, Jeff"))),
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hi, Frank")))))),
      s(:defn, :uses_strings,
        s(:args),
        s(:scope,
          s(:block,
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hello, Robert"))),
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "l33t h4x0r"))),
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hi, Frank")))))),
      s(:defn, :uses_strings,
        s(:args),
        s(:scope,
          s(:block,
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hello, Robert"))),
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "Hello, Jeff"))),
            s(:call, s(:ivar, :@names), :<<, s(:arglist, s(:str, "l33t h4x0r")))))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleIf < HeckleTestCase
  def setup
    @method_heckled = "uses_if"
    @nodes = s(:if)
    super
  end

  def test_if_original_tree
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

  def test_if_mutations
    expected = [
      s(:defn,
        :uses_if,
        s(:args),
        s(:scope,
          s(:block,
            s(:if,
              s(:call, nil, :some_func, s(:arglist)),
              nil,
              s(:if, s(:call, nil, :some_other_func, s(:arglist)), s(:return), nil))))),
      s(:defn,
        :uses_if,
        s(:args),
        s(:scope,
          s(:block,
            s(:if,
              s(:call, nil, :some_func, s(:arglist)),
              s(:if, s(:call, nil, :some_other_func, s(:arglist)), nil, s(:return)),
              nil))))
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleBoolean < HeckleTestCase
  def setup
    @method_heckled = "uses_boolean"
    @nodes = s(:true, :false)
    super
  end

  def test_boolean_original_tree
    expected = s(:defn, :uses_boolean,
                 s(:args),
                 s(:scope,
                   s(:block,
                     s(:lasgn, :a, s(:true)),
                     s(:lasgn, :b, s(:false)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_boolean_mutations
    expected = [
      s(:defn, :uses_boolean,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :a, s(:false)),
            s(:lasgn, :b, s(:false))))),
      s(:defn, :uses_boolean,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :a, s(:true)),
            s(:lasgn, :b, s(:true))))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleWhile < HeckleTestCase
  def setup
    @method_heckled = "uses_while"
    @nodes = s(:while)
    super
  end

  def test_while_original_tree
    expected =  s(:defn, :uses_while,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:while, s(:call, nil, :some_func, s(:arglist)),
                        s(:call, nil, :some_other_func, s(:arglist)), true))))

    assert_equal expected, @heckler.current_tree
  end

  def test_while_mutations
    expected = [
      s(:defn, :uses_while,
        s(:args),
        s(:scope,
          s(:block,
            s(:until, s(:call, nil, :some_func, s(:arglist)),
              s(:call, nil, :some_other_func, s(:arglist)), true))))]

    assert_mutations expected, @heckler
  end
end

class TestHeckleUntil < HeckleTestCase
  def setup
    @method_heckled = "uses_until"
    @nodes = s(:until)
    super
  end

  def test_until_original_tree
    expected =  s(:defn, :uses_until,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:until, s(:call, nil, :some_func, s(:arglist)),
                        s(:call, nil, :some_other_func, s(:arglist)), true))))

    assert_equal expected, @heckler.current_tree
  end

  def test_until_mutations
    expected = [
      s(:defn, :uses_until,
        s(:args),
        s(:scope,
          s(:block,
            s(:while, s(:call, nil, :some_func, s(:arglist)),
              s(:call, nil, :some_other_func, s(:arglist)), true))))]

    assert_mutations expected, @heckler
  end
end

class TestHeckleCall < HeckleTestCase
  def setup
    @method_heckled = "uses_call"
    super
  end

  def test_call_original_tree
    expected =  s(:defn, :uses_call,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:call,
                        s(:call, nil, :some_func, s(:arglist)),
                        :+,
                        s(:arglist, s(:call, nil, :some_other_func, s(:arglist)))))))

    assert_equal expected, @heckler.current_tree
  end

  def test_call_mutations
    expected = [
      s(:defn, :uses_call,
        s(:args),
        s(:scope,
          s(:block,
            s(:call,
              s(:call, nil, :some_func, s(:arglist)),
              :+,
              s(:arglist, s(:nil)))))),
      s(:defn, :uses_call,
        s(:args),
        s(:scope,
          s(:block,
            s(:call,
              s(:nil),
              :+,
              s(:arglist, s(:call, nil, :some_other_func, s(:arglist))))))),
      s(:defn, :uses_call,
        s(:args),
        s(:scope,
          s(:block,
            s(:nil)))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleCallblock < HeckleTestCase
  def setup
    @method_heckled = "uses_callblock"
    @nodes = s(:call)
    super
  end

  def test_callblock_original_tree
    expected =  s(:defn, :uses_callblock,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:iter,
                        s(:call, s(:call, nil, :x, s(:arglist)), :y, s(:arglist)),
                        nil,
                        s(:lit, 1)))))

    assert_equal expected, @heckler.current_tree
  end
  def test_callblock_mutations
    expected = [
      s(:defn, :uses_callblock,
        s(:args),
        s(:scope,
          s(:block,
            s(:iter,
              s(:call, s(:nil), :y, s(:arglist)),
              nil,
              s(:lit, 1)))))
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleClassMethod < HeckleTestCase
  def setup
    @method_heckled = "self.is_a_klass_method?"
    @nodes = s(:true)
    super
  end

  def test_class_method_original_tree
    expected =  s(:defs, s(:self), :is_a_klass_method?,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:true))))

    assert_equal expected, @heckler.current_tree
  end

  def test_class_methods_mutations
    expected = [
      s(:defs, s(:self), :is_a_klass_method?,
        s(:args),
        s(:scope,
          s(:block,
            s(:false))))
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleCvasgn < HeckleTestCase
  def setup
    @method_heckled = "uses_cvasgn"
    @nodes = s(:cvasgn)
    super
  end

  def test_cvasgn_original_tree
    expected =  s(:defn, :uses_cvasgn,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:cvasgn, :@@cvar, s(:lit, 5)),
                      s(:cvasgn, :@@cvar, s(:nil)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_cvasgn_mutations
    expected = [
      s(:defn, :uses_cvasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:cvasgn, :@@cvar, s(:lit, 5)),
            s(:cvasgn, :@@cvar, s(:lit, 42))))),
      s(:defn, :uses_cvasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:cvasgn, :@@cvar, s(:nil)),
            s(:cvasgn, :@@cvar, s(:nil))))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleIasgn < HeckleTestCase
  def setup
    @method_heckled = "uses_iasgn"
    @nodes = s(:iasgn)
    super
  end

  def test_iasgn_original_tree
    expected =  s(:defn, :uses_iasgn,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:iasgn, :@ivar, s(:lit, 5)),
                      s(:iasgn, :@ivar, s(:nil)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_iasgn_mutations
    expected = [
      s(:defn, :uses_iasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:iasgn, :@ivar, s(:lit, 5)),
            s(:iasgn, :@ivar, s(:lit, 42))))),
      s(:defn, :uses_iasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:iasgn, :@ivar, s(:nil)),
            s(:iasgn, :@ivar, s(:nil))))),
    ]

    assert_mutations expected, @heckler
  end

end

class TestHeckleGasgn < HeckleTestCase
  def setup
    @method_heckled = "uses_gasgn"
      s(:defn, :uses_cvasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:cvasgn, :@@cvar, s(:lit, 5)),
            s(:cvasgn, :@@cvar, s(:lit, 42)))))
    @nodes = s(:gasgn)
    super
  end

  def test_gasgn_original_tree
    expected =  s(:defn, :uses_gasgn,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:gasgn, :$gvar, s(:lit, 5)),
                      s(:gasgn, :$gvar, s(:nil)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_gasgn_mutations
    expected = [
      s(:defn, :uses_gasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:gasgn, :$gvar, s(:lit, 5)),
            s(:gasgn, :$gvar, s(:lit, 42))))),
      s(:defn, :uses_gasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:gasgn, :$gvar, s(:nil)),
            s(:gasgn, :$gvar, s(:nil))))),
    ]

    assert_mutations expected, @heckler
  end

end

class TestHeckleLasgn < HeckleTestCase
  def setup
    @method_heckled = "uses_lasgn"
    @nodes = s(:lasgn)
    super
  end

  def test_lasgn_original_tree
    expected =  s(:defn, :uses_lasgn,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:lasgn, :lvar, s(:lit, 5)),
                      s(:lasgn, :lvar, s(:nil)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_lasgn_mutations
    expected = [
      s(:defn, :uses_lasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :lvar, s(:nil)),
            s(:lasgn, :lvar, s(:nil))))),
      s(:defn, :uses_lasgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :lvar, s(:lit, 5)),
            s(:lasgn, :lvar, s(:lit, 42))))),
    ]

    assert_mutations expected, @heckler
  end
end

class TestHeckleMasgn < HeckleTestCase
  def setup
    @method_heckled = "uses_masgn"
    @nodes = s(:dasgn, :dasgn_curr, :iasgn, :gasgn, :lasgn)
    super
  end

  def test_masgn_original_tree
    expected =  s(:defn, :uses_masgn,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:masgn,
                        s(:array, s(:iasgn, :@a), s(:gasgn, :$b), s(:lasgn, :c)),
                        s(:array, s(:lit, 5), s(:lit, 6), s(:lit, 7))))))

    assert_equal expected, @heckler.current_tree
  end

  def test_masgn_mutations
    expected = [
      s(:defn, :uses_masgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:masgn,
              s(:array, s(:iasgn, :_heckle_dummy), s(:gasgn, :$b), s(:lasgn, :c)),
              s(:array, s(:lit, 5), s(:lit, 6), s(:lit, 7)))))),
      s(:defn, :uses_masgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:masgn,
              s(:array, s(:iasgn, :@a), s(:gasgn, :_heckle_dummy), s(:lasgn, :c)),
              s(:array, s(:lit, 5), s(:lit, 6), s(:lit, 7)))))),
      s(:defn, :uses_masgn,
        s(:args),
        s(:scope,
          s(:block,
            s(:masgn,
              s(:array,s(:iasgn, :@a), s(:gasgn, :$b), s(:lasgn, :_heckle_dummy)),
              s(:array, s(:lit, 5), s(:lit, 6), s(:lit, 7)))))),
    ]

    assert_mutations expected, @heckler
  end

end

class TestHeckleIter < HeckleTestCase
  def setup
    @method_heckled = "uses_iter"
    @nodes = [ :call, :lasgn ]
    super
  end

  def test_iter_original_tree
    expected =  s(:defn, :uses_iter,
                  s(:args),
                  s(:scope,
                    s(:block,
                      s(:lasgn, :x, s(:array, s(:lit, 1), s(:lit, 2), s(:lit, 3))),
                      s(:iter,
                        s(:call, s(:lvar, :x), :each, s(:arglist)),
                        s(:lasgn, :y), s(:lvar, :y)))))

    assert_equal expected, @heckler.current_tree
  end

  def test_iter_mutations
    expected = [
      s(:defn, :uses_iter,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :x, s(:nil)),
            s(:iter,
              s(:call, s(:lvar, :x), :each, s(:arglist)),
              s(:lasgn, :y), s(:lvar, :y))))),
      s(:defn, :uses_iter,
        s(:args),
        s(:scope,
          s(:block,
            s(:lasgn, :x, s(:array, s(:lit, 1), s(:lit, 2), s(:lit, 3))),
            s(:iter,
              s(:call, s(:lvar, :x), :each, s(:arglist)),
              s(:lasgn, :_heckle_dummy), s(:lvar, :y))))),
    ]


    assert_mutations expected, @heckler
  end
end


class TestHeckleFindsNestedClassAndModule < HeckleTestCase
  def setup
    @klass = "HeckleDummy::OuterNesting::InnerNesting::InnerClass"
    @method_heckled = "foo"
    @nodes = []
    super
  end

  def test_nested_class_and_module_original_tree
    expected =  s(:defn, :foo, s(:args), s(:scope,
                  s(:block,
                    s(:lit, 1337))))

    assert_equal expected, @heckler.current_tree
  end
end
