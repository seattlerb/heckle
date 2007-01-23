require 'rubygems'
require 'parse_tree'
require 'ruby2ruby'
require 'timeout'
require 'tempfile'

class String
  def to_class
    split(/::/).inject(Object) { |klass, name| klass.const_get(name) }
  end
end

class Heckle < SexpProcessor
  VERSION = '1.2.0'
  MUTATABLE_NODES = [:if, :lit, :str, :true, :false, :while, :until]
  WINDOZE = RUBY_PLATFORM =~ /mswin/
  NULL_PATH = WINDOZE ? 'NUL:' : '/dev/null'

  attr_accessor(:klass_name, :method_name, :klass, :method, :mutatees,
                :original_tree, :mutation_count, :node_count,
                :failures, :count)

  @@debug = false
  @@guess_timeout = true
  @@timeout = 60 # default to something longer (can be overridden by runners)

  def self.debug=(value)
    @@debug = value
  end

  def self.timeout=(value)
    @@timeout = value
    @@guess_timeout = false # We've set the timeout, don't guess
  end

  def self.guess_timeout?
    @@guess_timeout
  end

  def initialize(klass_name=nil, method_name=nil, reporter = Reporter.new)
    super()

    @klass_name = klass_name
    @method_name = method_name.intern if method_name

    @klass = klass_name.to_class

    @method = nil
    @reporter = reporter

    self.strict = false
    self.auto_shift_type = true
    self.expected = Array

    @mutatees = Hash.new
    @mutation_count = Hash.new
    @node_count = Hash.new
    @count = 0

    MUTATABLE_NODES.each {|type| @mutatees[type] = [] }

    @failures = []

    @mutated = false

    grab_mutatees

    @original_tree = current_tree.deep_clone
    @original_mutatees = mutatees.deep_clone
  end

  ############################################################
  ### Overwrite test_pass? for your own Heckle runner.
  def tests_pass?
    raise NotImplementedError
  end

  def run_tests
    if tests_pass? then
      record_passing_mutation
    else
      @reporter.report_test_failures
    end
  end

  ############################################################
  ### Running the script

  def validate
    if mutations_left == 0
      @reporter.no_mutations(method_name)
      return
    end

    @reporter.method_loaded(klass_name, method_name, mutations_left)

    until mutations_left == 0
      @reporter.remaining_mutations(mutations_left)
      reset_tree
      begin
        process current_tree
        silence_stream { timeout(@@timeout) { run_tests } }
      rescue SyntaxError => e
        @reporter.warning "Mutation caused a syntax error:\n\n#{e.message}}"
      rescue Timeout::Error
        @reporter.warning "Your tests timed out. Heckle may have caused an infinite loop."
      end
    end

    reset # in case we're validating again. we should clean up.

    unless @failures.empty?
      @reporter.no_failures
      original = RubyToRuby.new.process(@original)
      @failures.each do |failure|
        @reporter.failure(original, failure)
      end
    else
      @reporter.no_surviving_mutants
    end
  end

  def record_passing_mutation
    @failures << current_code
  end

  def heckle(exp)
    @original = exp.deep_clone
    src = begin
            RubyToRuby.new.process(exp)
          rescue => e
            puts "Error: #{e.message} with: #{klass_name}##{method_name}: #{@original.inspect}"
            raise e
          end
    @reporter.replacing(klass_name, method_name, src) if @@debug

    clean_name = method_name.to_s.gsub(/self\./, '')
    self.count += 1
    new_name = "h#{count}_#{clean_name}"

    klass = aliasing_class method_name
    klass.send :remove_method, new_name rescue nil
    klass.send :alias_method, new_name, clean_name
    klass.send :remove_method, clean_name rescue nil

    @klass.class_eval src, "(#{new_name})"
  end

  ############################################################
  ### Processing sexps

  def process_defn(exp)
    self.method = exp.shift
    result = [:defn, method]
    result << process(exp.shift) until exp.empty?
    heckle(result) if method == method_name

    return result
  ensure
    @mutated = false
    reset_node_count
  end

  def process_lit(exp)
    mutate_node [:lit, exp.shift]
  end

  def mutate_lit(exp)
    case exp[1]
    when Fixnum, Float, Bignum
      [:lit, exp[1] + rand_number]
    when Symbol
      [:lit, rand_symbol]
    when Regexp
      [:lit, Regexp.new(Regexp.escape(rand_string))]
    when Range
      [:lit, rand_range]
    end
  end

  def process_str(exp)
    mutate_node [:str, exp.shift]
  end

  def mutate_str(node)
    [:str, rand_string]
  end

  def process_if(exp)
    mutate_node [:if, process(exp.shift), process(exp.shift), process(exp.shift)]
  end

  def mutate_if(node)
    [:if, node[1], node[3], node[2]]
  end

  def process_true(exp)
    mutate_node [:true]
  end

  def mutate_true(node)
    [:false]
  end

  def process_false(exp)
    mutate_node [:false]
  end

  def mutate_false(node)
    [:true]
  end

  def process_while(exp)
    cond, body, head_controlled = grab_conditional_loop_parts(exp)
    mutate_node [:while, cond, body, head_controlled]
  end

  def mutate_while(node)
    [:until, node[1], node[2], node[3]]
  end

  def process_until(exp)
    cond, body, head_controlled = grab_conditional_loop_parts(exp)
    mutate_node [:until, cond, body, head_controlled]
  end

  def mutate_until(node)
    [:while, node[1], node[2], node[3]]
  end

  def mutate_node(node)
    raise UnsupportedNodeError unless respond_to? "mutate_#{node.first}"
    increment_node_count node

    if should_heckle? node
      increment_mutation_count node
      return send("mutate_#{node.first}", node)
    else
      node
    end
  end

  ############################################################
  ### Tree operations

  def walk_and_push(node)
    return unless node.respond_to? :each
    return if node.is_a? String
    node.each { |child| walk_and_push(child) }
    if MUTATABLE_NODES.include? node.first
      @mutatees[node.first.to_sym].push(node)
      mutation_count[node] = 0
    end
  end

  def grab_mutatees
    walk_and_push(current_tree)
  end

  def current_tree
    ParseTree.translate(klass_name.to_class, method_name)
  end

  def reset
    reset_tree
    reset_mutatees
    reset_mutation_count
  end

  def reset_tree
    return unless original_tree != current_tree
    @mutated = false

    self.count += 1

    clean_name = method_name.to_s.gsub(/self\./, '')
    new_name = "h#{count}_#{clean_name}"

    klass = aliasing_class method_name

    klass.send :undef_method, new_name rescue nil
    klass.send :alias_method, new_name, clean_name
    klass.send :alias_method, clean_name, "h1_#{clean_name}"
  end

  def reset_mutatees
    @mutatees = @original_mutatees.deep_clone
  end

  def reset_mutation_count
    mutation_count.each {|k,v| mutation_count[k] = 0}
  end

  def reset_node_count
    node_count.each {|k,v| node_count[k] = 0}
  end

  def increment_node_count(node)
    if node_count[node].nil?
      node_count[node] = 1
    else
      node_count[node] += 1
    end
  end

  def increment_mutation_count(node)
    # So we don't re-mutate this later if the tree is reset
    mutation_count[node] += 1
    @mutatees[node.first].delete_at(@mutatees[node.first].index(node))
    @mutated = true
  end

  ############################################################
  ### Convenience methods

  def aliasing_class(method_name)
    method_name.to_s =~ /self\./ ? class << @klass; self; end : @klass
  end

  def should_heckle?(exp)
    return false unless method == method_name
    mutation_count[exp] = 0 if mutation_count[exp].nil?
    return false if node_count[exp] <= mutation_count[exp]
    ( mutatees[exp.first.to_sym] || [] ).include?(exp) && !already_mutated?
  end

  def grab_conditional_loop_parts(exp)
    cond = process(exp.shift)
    body = process(exp.shift)
    head_controlled = exp.shift
    return cond, body, head_controlled
  end

  def already_mutated?
    @mutated
  end

  def mutations_left
    sum = 0
    @mutatees.each {|mut| sum += mut.last.size }
    sum
  end

  def current_code
    RubyToRuby.translate(klass_name.to_class, method_name)
  end

  def rand_number
    (rand(10) + 1)*((-1)**rand(2))
  end

  def rand_string
    size = rand(50)
    str = ""
    size.times { str << rand(126).chr }
    str
  end

  def rand_symbol
    letters = ('a'..'z').to_a + ('A'..'Z').to_a
    str = ""
    (rand(50) + 1).times { str << letters[rand(letters.size)] }
    :"#{str}"
  end

  def rand_range
    min = rand(50)
    max = min + rand(50)
    min..max
  end

  def silence_stream
    dead = File.open("/dev/null", "w")

    $stdout.flush
    $stderr.flush

    oldstdout = $stdout.dup
    oldstderr = $stderr.dup

    $stdout.reopen(dead)
    $stderr.reopen(dead)

    result = yield

  ensure
    $stdout.flush
    $stderr.flush

    $stdout.reopen(oldstdout)
    $stderr.reopen(oldstderr)
    result
  end

  class Reporter
    def no_mutations(method_name)
      warning "#{method_name} has a thick skin. There's nothing to heckle."
    end

    def method_loaded(klass_name, method_name, mutations_left)
      info "#{klass_name}\##{method_name} loaded with #{mutations_left} possible mutations"
    end

    def remaining_mutations(mutations_left)
      puts "#{mutations_left} mutations remaining..."
    end

    def warning(message)
      puts
      puts "!" * 70
      puts "!!! #{message}"
      puts "!" * 70
      puts
    end

    def info(message)
      puts
      puts "*"*70
      puts "***  #{message}"
      puts "*"*70
      puts
    end

    def no_failures
      puts "\nThe following mutations didn't cause test failures:\n"
    end

    def failure(original, failure)
      windoze  = /win32/ =~ RUBY_PLATFORM
      diff = (windoze ? 'diff.exe' : 'diff')

      length = [original.split(/\n/).size, failure.split(/\n/).size].max

      Tempfile.open("orig") do |a|
        a.puts(original)
        a.flush

        Tempfile.open("fail") do |b|
          b.puts(failure)
          b.flush

          diff_flags = " "

          output = `#{diff} -U #{length} --label original #{a.path} --label mutation #{b.path}`
          puts output.sub(/^@@.*?\n/, '')
          puts
        end
      end
    end

    def no_surviving_mutants
      puts "No mutants survived. Cool!\n\n"
    end

    def replacing(klass_name, method_name, src)
      puts "Replacing #{klass_name}##{method_name} with:\n\n#{src}\n"
    end

    def report_test_failures
      puts "Tests failed -- this is good"
    end
  end
end
