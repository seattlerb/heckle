#!/usr/bin/env ruby
#
#  Created by Kevin Clark on 2006-11-10.
#  Copyright (c) 2006. All rights reserved.

require "test/unit"

$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])
require "heckled"

class TestHeckled < Test::Unit::TestCase
  def setup
    @heckled = Heckled.new
  end
  def test_uses_strings
    @heckled.uses_strings
    assert_equal ["Hello, Robert", "Hello, Jeff", "Hi, Frank"], @heckled.names
  end
  
  def test_uses_infinite_loop
    @heckled.uses_infinite_loop?
  end
  
  def test_is_a_klass_method
    assert_equal true, Heckled.is_a_klass_method?
  end
end