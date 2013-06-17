require 'optparse'
require 'heckle'
require 'heckle/minitest_heckler'

module Heckle
  class Runner
    def self.run argv=ARGV
      options = parse_args argv, argv.shift, argv.shift

      new(options).run
    end

    def self.parse_args argv, klass_name, method_name
      options = {
        :force => false,
        :nodes => Heckle::Heckler::MUTATABLE_NODES,
        :debug => false,
        :focus => false,
        :timeout => 5,
        :test_pattern => 'test/**/{test_*,*_test}.rb',
        :klass_name => klass_name,
        :method_name => method_name
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

          options[:nodes] = Heckle::Heckler::ASGN_NODES
        end

        opts.on("-b", "--branches", "Only mutate branches") do
          puts "!"*70
          puts "!!! Heckling branches only"
          puts "!"*70
          puts

          options[:nodes] = Heckle::Heckler::BRANCH_NODES
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
                "Possible values: #{Heckle::Heckler::MUTATABLE_NODES.join(',')}") do |opt|
          nodes = opt.split(',').collect {|n| n.to_sym }
          options[:nodes] = nodes
          puts "Mutating nodes: #{nodes.inspect}"
        end

        opts.on("-x", "--exclude-nodes NODES", "Nodes to exclude") do |opt|
          exclusions = opt.split(',').collect {|n| n.to_sym }
          options[:nodes] = options[:nodes] - exclusions
          puts "Mutating without nodes: #{exclusions.inspect}"
        end

        opts.on("-I", "--include INCLUDES", "specify $LOAD_PATH directories") do |opt|
          opt.split(":").each {|dir| $LOAD_PATH << dir }
        end

        opts.parse! argv

        unless options[:klass_name] && options[:method_name]
          p options
          p opts
          abort "need a class name and method name"
        end
      end

      # TODO: Pass options to Heckle's initializer instead.
      #Heckle.debug = options[:debug]
      #Heckle.timeout = options[:timeout]

      options
    end

    # TODO: this sucks
    def heckler
      MiniTestHeckler
    end

    def initialize options={}
      @options = options
    end

    def run
      heckler.new(@options).validate
    end
  end
end
