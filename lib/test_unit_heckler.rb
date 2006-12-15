#!/usr/bin/env ruby

require 'test/unit/autorunner'
require 'heckle'

class TestUnitHeckler < Heckle
  def initialize(klass_name=nil, method_name=nil)
    super(klass_name, method_name)
  end
  
  def tests_pass?
    Test::Unit::AutoRunner.run
  end
end