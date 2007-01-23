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

    self.timeout = adjusted_timeout

    puts "Initial tests pass. Let's rumble."

    klass_methods = klass.singleton_methods(false).collect {|meth| "self.#{meth}"}
    methods = method_name ? Array(method_name) : klass.instance_methods(false) + klass_methods

    results = methods.map do |method_name|
      self.new(klass_name, method_name).validate
    end.compact # nil == thick skin

    if results.all? then
      puts "All heckling was thwarted! YAY!!!"
    else
      count = results.find_all { |o| o }.size
      puts "#{count} methods were successfully heckled."
      puts "Improve the tests and try again."
    end

    results.all?
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
