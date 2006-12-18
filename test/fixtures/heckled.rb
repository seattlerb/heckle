class Heckled
  attr_accessor :names
  
  def initialize
    @names = []
  end
  
  def uses_many_things
    i = 1
    while i < 10
      i += 1
      until some_func
        some_other_func
      end
      return true if "hi there" == "changeling"
      return false
    end 
    i
  end
  
  def uses_while
    while some_func
      some_other_func
    end
  end

  def uses_until
    until some_func
      some_other_func
    end
  end
  
  def uses_numeric_literals
    i = 1
    i += 2147483648
    i -= 3.5
  end
  
  def uses_strings
    @names << "Hello, Robert"
    @names << "Hello, Jeff"
    @names << "Hi, Frank"
  end
    
  def uses_different_types
    i = 1
    b = "Hello, Joe"
    c = 3.3
  end
  
  def uses_the_same_literal
    i = 1
    i = 1
    i = 1
  end
    
  def uses_if
    if some_func
      if some_other_func
        return
      end
    end
  end
  
  def uses_boolean
    true
    false
  end
  
  def uses_unless
    unless true
      if false
        return
      end
    end
  end
  
  def uses_symbols
    i = :blah
    i = :blah
    i = :and_blah
  end
  
  def uses_regexes
    i = /a.*/
    i = /c{2,4}+/
    i = /123/
  end
  
  def uses_ranges
    i = 6..100
    i = -1..9
    i = 1..4
  end
  
  def uses_nothing
  end
  
  private
  
  def some_func; end
  def some_other_func; end
end
