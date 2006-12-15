class Heckled
  attr_accessor :names
  
  def initialize
    @names = []
  end
  
  def uses_while
    i = 1
    while i < 10
      i += 1
    end 
    i
  end

  def uses_until
    i = 1
    until i >= 10
      i += 1
    end
    i
  end
  
  def uses_numeric_literals
    i = 1
    i += 10
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
    if true
      if false
        return
      end
    end
  end
  
  def uses_unless
    unless true
      if false
        return
      end
    end
  end
end
