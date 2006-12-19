#!/usr/bin/env ruby

require 'test/unit/autorunner'
require 'heckle'

class TestUnitHeckler < Heckle::Base
  @@test_pattern = 'test/test_*.rb'
  @@tests_loaded = false;

  def self.test_pattern=(value)
    @@test_pattern = value
  end
  
  def self.load_test_files
    @@tests_loaded = true
    Dir.glob(@@test_pattern).each {|test| require test}
  end

  def self.validate(klass_name)
    load_test_files
    klass = klass_name.to_class
    klass.instance_methods(false).each do |method_name|
      heckler = self.new(klass_name, method_name)
      heckler.test_and_validate
    end
  end

  def initialize(klass_name=nil, method_name=nil)
    super(klass_name, method_name)
    self.class.load_test_files unless @@tests_loaded
  end
  
  def test_and_validate
    if silence_stream(STDOUT) { tests_pass? } then
      puts "Initial tests pass. Let's rumble."
      validate
    else
      puts "Tests failed... fix and run heckle again"
    end
  end
  
  def tests_pass?
    Test::Unit::AutoRunner.run
  end
end
