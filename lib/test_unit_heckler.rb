#!/usr/bin/env ruby

require 'test/unit/autorunner'
require 'heckle'
$: << 'lib' << 'test'

class TestUnitHeckler < Heckle
  @@test_pattern = 'test/test_*.rb'
  @@tests_loaded = false;

  def self.test_pattern=(value)
    @@test_pattern = value
  end

  def self.load_test_files
    @@tests_loaded = true
    Dir.glob(@@test_pattern).each {|test| require test}
  end

  def self.validate(klass_name, method_name = nil)
    load_test_files
    klass = klass_name.to_class

    initial_time = Time.now
    unless self.new(klass_name).tests_pass? then
      abort "Initial run of tests failed... fix and run heckle again"
    end
    
    if self.guess_timeout?
      running_time = (Time.now - initial_time)
      adjusted_timeout = (running_time * 2 < 5) ? 5 : (running_time * 2)
      self.timeout = adjusted_timeout
      puts "Setting timeout at #{adjusted_timeout} seconds." if @@debug
      
    end
    
    puts "Initial tests pass. Let's rumble."

    methods = method_name ? Array(method_name) : klass.instance_methods(false)

    methods.each do |method_name|
      self.new(klass_name, method_name).validate
    end
  end

  def initialize(klass_name=nil, method_name=nil)
    super(klass_name, method_name)
    self.class.load_test_files unless @@tests_loaded
  end

  def tests_pass?
    silence_stream do
      Test::Unit::AutoRunner.run
    end
  end
end
