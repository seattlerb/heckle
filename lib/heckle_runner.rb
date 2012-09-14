require 'optparse'
require 'heckle'

class HeckleRunner
  def self.run argv=ARGV
    options = parse_args argv

    class_or_module, method = argv.shift, argv.shift

    new(class_or_module, method, options).run
  end

  def self.parse_args argv
    options = {
      :force => false,
      :nodes => Heckle::MUTATABLE_NODES,
      :debug => false,
      :focus => false,
      :timeout => 5,
      :test_pattern => 'test/test_*.rb',
    }

    OptionParser.new do |opts|
      opts.version = Heckle::VERSION
      opts.program_name = File.basename $0
      opts.banner = "Usage: #{opts.program_name} class_name [method_name]"
      opts.on("-v", "--verbose", "Loudly explain heckle run") do
        options[:debug] = true
      end

      opts.on("-t", "--tests TEST_PATTERN",
              "Location of tests (glob)") do |pattern|
        options[:test_pattern] = pattern
      end

      opts.on("-F", "--force", "Ignore initial test failures",
              "Best used with --focus") do
        options[:force] = true
      end

      opts.on(      "--assignments", "Only mutate assignments") do
        puts "!"*70
        puts "!!! Heckling assignments only"
        puts "!"*70
        puts

        options[:nodes] = Heckle::ASGN_NODES
      end

      opts.on("-b", "--branches", "Only mutate branches") do
        puts "!"*70
        puts "!!! Heckling branches only"
        puts "!"*70
        puts

        options[:nodes] = Heckle::BRANCH_NODES
      end

      opts.on("-f", "--focus", "Apply the eye of sauron") do
        puts "!"*70
        puts "!!! Running in focused mode. FEEL THE EYE OF SAURON!!!"
        puts "!"*70
        puts

        options[:focus] = true
      end

      opts.on("-T", "--timeout SECONDS", "The maximum time for a test run in seconds",
                                         "Used to catch infinite loops") do |timeout|
        timeout = timeout.to_i
        puts "Setting timeout at #{timeout} seconds."
        options[:timeout] = timeout
      end

      opts.on("-n", "--nodes NODES", "Nodes to mutate",
              "Possible values: #{Heckle::MUTATABLE_NODES.join(',')}") do |opt|
        nodes = opt.split(',').collect {|n| n.to_sym }
        options[:nodes] = nodes
        puts "Mutating nodes: #{nodes.inspect}"
      end

      opts.on("-x", "--exclude-nodes NODES", "Nodes to exclude") do |opt|
        exclusions = opt.split(',').collect {|n| n.to_sym }
        options[:nodes] = options[:nodes] - exclusions
        puts "Mutating without nodes: #{exclusions.inspect}"
      end
    end.parse! argv

    options
  end

  def initialize class_or_module, method, options={}
    @class_or_module = class_or_module
    @method = method
    @options = options
  end

  def run
    Dir.glob(@options[:test_pattern]).each {|t| require File.expand_path(t) }

    MiniTestHeckler.new(@class_or_module, @method, @options[:nodes]).validate
  end

  class MiniTestHeckler < Heckle
    def initialize(class_or_module, method, nodes)
      super
      @tu = MiniTest::Unit.new
    end

    # TODO: This doesn't work.
    def tests_pass?
      silence do
        @tu.run_tests

        (@tu.errors + @tu.failures) == 0
      end
    end

    # TODO: Windows.
    def silence
      original = MiniTest::Unit.output
      MiniTest::Unit.output = File.open("/dev/null", "w")

      yield
    ensure
      MiniTest::Unit.output = original
    end
  end
end
