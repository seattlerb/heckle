begin
  gem 'minitest'
rescue Gem::LoadError
end

require 'minitest/unit'

if MiniTest::Unit.respond_to?(:autorun)
  class MiniTest::Unit
    def self.autorun
    end
  end
end

module Heckle
  class MiniTestHeckler < Heckle::Heckler
    def initialize(options={})
      $LOAD_PATH << 'lib'
      $LOAD_PATH << 'test'

      Dir.glob(options[:test_pattern]).uniq.each {|t| load t }

      super
    end

    def tests_pass?
      silence do
        MiniTest::Unit.runner = nil

        MiniTest::Unit.new.run

        runner = MiniTest::Unit.runner

        runner.failures == 0 && runner.errors == 0
      end
    end

    # TODO: Windows.
    def silence
      # return yield if Heckle.debug

      begin
        original = MiniTest::Unit.output
        MiniTest::Unit.output = File.open("/dev/null", "w")

        yield
      ensure
        MiniTest::Unit.output = original
      end
    end
  end
end
