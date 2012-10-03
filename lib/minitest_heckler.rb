class MiniTestHeckler < Heckle
  def initialize(class_or_module, method, options)
    Dir.glob(options[:test_pattern]).each {|t| load File.expand_path(t) }

    super(class_or_module, method, options[:nodes])
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
    return yield if Heckle.debug

    begin
      original = MiniTest::Unit.output
      MiniTest::Unit.output = File.open("/dev/null", "w")

      yield
    ensure
      MiniTest::Unit.output = original
    end
  end
end
