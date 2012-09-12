require 'minitest/autorun'
require 'heckle_runner'

# Tests needed:
# * if no method, loads all local methods
# * should raise an exception if the class/module can't be found
# * should raise an exception if the method can't be found
# * Tests for option parsing.

class TestHeckleRunnerRun < MiniTest::Unit::TestCase
  @@dummy_dir = File.expand_path('test/fixtures/minitest_project')
  dummy_lib = File.join(@@dummy_dir, 'lib')

  $LOAD_PATH << dummy_lib

  def setup
    super

    @old_pwd = Dir.pwd
    Dir.chdir @@dummy_dir

    # See MiniTest's test/minitest/metametameta.rb
    @output = StringIO.new("")
    MiniTest::Unit::TestCase.reset
    MiniTest::Unit.runner = nil
    MiniTest::Unit.output = @output
  end

  def teardown
    super
    Dir.chdir @old_pwd
    MiniTest::Unit.output = $stdout
  end

  def test_run_with_full_test_coverage
    out, _ = capture_io do
      HeckleRunner.run %w[Doubler double]
    end

    assert_match %r{No mutants survived.}, out
  end

  def test_run_with_partial_coverage
    out, _ = capture_io do
      HeckleRunner.run %w[Doubler double --tests "test/test_doubler_with_a_number.rb"]
    end

    refute_match %r{No mutants survived.}, out
  end
end
