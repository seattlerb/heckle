$:.unshift(File.dirname(__FILE__) + '/fixtures')
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit/testcase'
require 'test/unit' if $0 == __FILE__
require 'test_unit_heckler'
require 'heckled'

class TestHeckle < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_many_things")
  end
  
  def test_should_set_original_tree
    expected = [:defn,
     :uses_many_things,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 1]],
       [:while,
        [:call, [:lvar, :i], :<, [:array, [:lit, 10]]],
        [:block,
         [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 1]]]],
         [:until, [:vcall, :some_func], [:vcall, :some_other_func], true],
         [:if,
          [:call, [:str, "hi there"], :==, [:array, [:str, "changeling"]]],
          [:return, [:true]],
          nil],
         [:return, [:false]]],
        true],
       [:lvar, :i]]]]
    
    assert_equal expected, @heckler.original_tree
  end
  
  def test_should_grab_mutatees_from_method
    # expected is from tree of uses_while
    expected = {
     :lit=>[[:lit, 1], [:lit, 10], [:lit, 1]],
     :if=>[[:if,
         [:call, [:str, "hi there"], :==, [:array, [:str, "changeling"]]],
         [:return, [:true]],
         nil]],
     :str => [[:str, "hi there"], [:str, "changeling"]],
     :true => [[:true]],
     :false => [[:false]],
     :while=>
       [[:while,
         [:call, [:lvar, :i], :<, [:array, [:lit, 10]]],
         [:block,
          [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 1]]]],
          [:until, [:vcall, :some_func], [:vcall, :some_other_func], true],
          [:if,
           [:call, [:str, "hi there"], :==, [:array, [:str, "changeling"]]],
           [:return, [:true]],
           nil],
          [:return, [:false]]],
         true]],
      :until => [[:until, [:vcall, :some_func], [:vcall, :some_other_func], true]]
    }
     
    assert_equal expected, @heckler.mutatees
  end

  def test_reset
    original_tree = @heckler.current_tree.deep_clone
    original_mutatees = @heckler.mutatees.deep_clone
    
    3.times { @heckler.process(@heckler.current_tree) }
    
    assert_not_equal original_tree, @heckler.current_tree
    assert_not_equal original_mutatees, @heckler.mutatees
    
    @heckler.reset
    assert_equal original_tree, @heckler.current_tree
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
  
  def teardown
    @heckler.reset
  end
end

class Heckle
  def rand(*args)
    5
  end
end

class TestHeckleNumbers < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_numeric_literals")
  end
      
  def test_literals_should_flip_one_at_a_time
    expected = [:defn,
     :uses_numeric_literals,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 6]],
       [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 2147483648]]]],
       [:lasgn, :i, [:call, [:lvar, :i], :-, [:array, [:lit, 3.5]]]]]]]
    
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_numeric_literals,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 2147483653]]]],
       [:lasgn, :i, [:call, [:lvar, :i], :-, [:array, [:lit, 3.5]]]]]]]
    
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_numeric_literals,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:call, [:lvar, :i], :+, [:array, [:lit, 2147483648]]]],
       [:lasgn, :i, [:call, [:lvar, :i], :-, [:array, [:lit, 8.5]]]]]]]
    
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
  
  def teardown
    @heckler.reset
  end
end

class TestHeckleSymbols < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_symbols")
  end
  
  def test_default_structure
    expected = [:defn,
     :uses_symbols,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, :blah]],
       [:lasgn, :i, [:lit, :blah]],
       [:lasgn, :i, [:lit, :and_blah]]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  
  def test_should_randomize_symbol
    expected = [:defn,
     :uses_symbols,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, :"l33t h4x0r"]],
       [:lasgn, :i, [:lit, :blah]],
       [:lasgn, :i, [:lit, :and_blah]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  
    @heckler.reset_tree
  
    expected = [:defn,
     :uses_symbols,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, :blah]],
       [:lasgn, :i, [:lit, :"l33t h4x0r"]],
       [:lasgn, :i, [:lit, :and_blah]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_symbols,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, :blah]],
       [:lasgn, :i, [:lit, :blah]],
       [:lasgn, :i, [:lit, :"l33t h4x0r"]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleRegexes < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_regexes")
  end
  
  def test_default_structure
    expected = [:defn,
     :uses_regexes,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, /a.*/]],
       [:lasgn, :i, [:lit, /c{2,4}+/]],
       [:lasgn, :i, [:lit, /123/]]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  
  def test_should_randomize_symbol
    expected = [:defn,
     :uses_regexes,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, /l33t\ h4x0r/]],
       [:lasgn, :i, [:lit, /c{2,4}+/]],
       [:lasgn, :i, [:lit, /123/]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_regexes,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, /a.*/]],
       [:lasgn, :i, [:lit, /l33t\ h4x0r/]],
       [:lasgn, :i, [:lit, /123/]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  
    @heckler.reset_tree
  
    expected = [:defn,
     :uses_regexes,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, /a.*/]],
       [:lasgn, :i, [:lit, /c{2,4}+/]],
       [:lasgn, :i, [:lit, /l33t\ h4x0r/]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleRanges < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_ranges")
  end
  
  def test_default_structure
    expected = [:defn,
     :uses_ranges,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 6..100]],
       [:lasgn, :i, [:lit, -1..9]],
       [:lasgn, :i, [:lit, 1..4]]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  def test_should_randomize_symbol
    expected = [:defn,
     :uses_ranges,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 5..10]],
       [:lasgn, :i, [:lit, -1..9]],
       [:lasgn, :i, [:lit, 1..4]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_ranges,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 6..100]],
       [:lasgn, :i, [:lit, 5..10]],
       [:lasgn, :i, [:lit, 1..4]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  
    @heckler.reset_tree
  
    expected = [:defn,
     :uses_ranges,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 6..100]],
       [:lasgn, :i, [:lit, -1..9]],
       [:lasgn, :i, [:lit, 5..10]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end


class TestHeckleSameLiteral < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_the_same_literal")
  end

  def teardown
    @heckler.reset
  end
  
  def test_original_tree
    expected = [:defn,
     :uses_the_same_literal,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:lit, 1]]]]]
    
    assert_equal expected, @heckler.current_tree
  end
  
  def test_literals_should_flip_one_at_a_time
    # structure of uses_numeric_literals with first literal +5 (from stubbed rand)
    expected = [:defn,
     :uses_the_same_literal,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 6]],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:lit, 1]]]]]
    
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
        
    expected = [:defn,
     :uses_the_same_literal,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:lit, 6]],
       [:lasgn, :i, [:lit, 1]]]]]
       
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_the_same_literal,
     [:scope,
      [:block,
       [:args],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:lit, 1]],
       [:lasgn, :i, [:lit, 6]]]]]
       
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class Heckle
  def rand_string
    "l33t h4x0r"
  end
end

class TestHeckleStrings < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_strings")
  end
  
  def teardown
    @heckler.reset
  end
  
  def test_default_structure
    expected = [:defn,
     :uses_strings,
     [:scope,
      [:block,
       [:args],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hello, Robert"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hello, Jeff"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hi, Frank"]]]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  def test_should_heckle_string_literals
    expected = [:defn,
     :uses_strings,
     [:scope,
      [:block,
       [:args],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "l33t h4x0r"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hello, Jeff"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hi, Frank"]]]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_strings,
     [:scope,
      [:block,
       [:args],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hello, Robert"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "l33t h4x0r"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hi, Frank"]]]]]]
    
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
    
    expected = [:defn,
     :uses_strings,
     [:scope,
      [:block,
       [:args],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hello, Robert"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "Hello, Jeff"]]],
       [:call, [:ivar, :@names], :<<, [:array, [:str, "l33t h4x0r"]]]]]]
    
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleIfs < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_if")
  end
  
  def teardown
    @heckler.reset
  end
  
  def test_default_structure
    expected = [:defn,
     :uses_if,
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
    expected = [:defn,
     :uses_if,
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
        
    expected = [:defn,
     :uses_if,
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

class TestHeckleBooleans < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_boolean")
  end
  
  def teardown
    @heckler.reset
  end
  
  def test_default_structure
    expected = [:defn, :uses_boolean, [:scope, [:block, [:args], [:true], [:false]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  
  def test_should_flip_true_to_false_and_false_to_true
    expected = [:defn, :uses_boolean, [:scope, [:block, [:args], [:false], [:false]]]]
    
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
    
    @heckler.reset_tree
    
    expected = [:defn, :uses_boolean, [:scope, [:block, [:args], [:true], [:true]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleWhile < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_while")
  end
  
  def teardown
    @heckler.reset
  end
  
  def test_default_structure
    expected = [:defn,
     :uses_while,
     [:scope,
      [:block,
       [:args],
       [:while, [:vcall, :some_func], [:vcall, :some_other_func], true]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  def test_flips_while_to_until
    expected = [:defn,
     :uses_while,
     [:scope,
      [:block,
       [:args],
       [:until, [:vcall, :some_func], [:vcall, :some_other_func], true]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end

class TestHeckleUntil < Test::Unit::TestCase
  def setup
    @heckler = Heckle.new("Heckled", "uses_until")
  end
  
  def teardown
    @heckler.reset
  end
  
  def test_default_structure
    expected = [:defn,
     :uses_until,
     [:scope,
      [:block,
       [:args],
       [:until, [:vcall, :some_func], [:vcall, :some_other_func], true]]]]
    assert_equal expected, @heckler.current_tree
  end
  
  def test_flips_until_to_while
    expected = [:defn,
     :uses_until,
     [:scope,
      [:block,
       [:args],
       [:while, [:vcall, :some_func], [:vcall, :some_other_func], true]]]]
    @heckler.process(@heckler.current_tree)
    assert_equal expected, @heckler.current_tree
  end
end
