require 'rubygems'
require 'parse_tree'
require 'ruby2ruby'
require 'timeout'
require 'tempfile'

class String # :nodoc:
  def to_class
    split(/::/).inject(Object) { |klass, name| klass.const_get(name) }
  end
end

##
# Test Unit Sadism

class Heckle < SexpProcessor

  ##
  # The version of Heckle you are using.

  VERSION = '1.4.1'

  ##
  # Branch node types.

  BRANCH_NODES = [:if, :until, :while]

  ##
  # Is this platform MS Windows-like?

  WINDOZE = RUBY_PLATFORM =~ /mswin/

  ##
  # Path to the bit bucket.

  NULL_PATH = WINDOZE ? 'NUL:' : '/dev/null'

  ##
  # diff(1) executable

  DIFF = WINDOZE ? 'diff.exe' : 'diff'

  ##
  # Mutation count

  attr_accessor :count

  ##
  # Mutations that caused failures

  attr_accessor :failures

  ##
  # Class being heckled

  attr_accessor :klass

  ##
  # Name of class being heckled

  attr_accessor :klass_name

  ##
  # Method being heckled

  attr_accessor :method

  ##
  # Name of method being heckled

  attr_accessor :method_name

  attr_accessor :mutatees # :nodoc:
  attr_accessor :mutation_count # :nodoc:
  attr_accessor :node_count # :nodoc:
  attr_accessor :original_tree # :nodoc:

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

  ##
  # Creates a new Heckle that will heckle +klass_name+ and +method_name+,
  # sending results to +reporter+.

  def initialize(klass_name = nil, method_name = nil,
                 nodes = Heckle::MUTATABLE_NODES, reporter = Reporter.new)
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

    @mutatable_nodes = nodes
    @mutatable_nodes.each {|type| @mutatees[type] = [] }

    @failures = []

    @mutated = false

    grab_mutatees

    @original_tree = current_tree.deep_clone
    @original_mutatees = mutatees.deep_clone
  end

  ##
  # Overwrite test_pass? for your own Heckle runner.

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
      @failures.each do |failure|
        original = RubyToRuby.new.process(@original_tree.deep_clone)
        @reporter.failure(original, failure)
      end
      false
    else
      @reporter.no_surviving_mutants
      true
    end
  end

  def record_passing_mutation
    @failures << current_code
  end

  def heckle(exp)
    exp_copy = exp.deep_clone
    src = begin
            RubyToRuby.new.process(exp)
          rescue => e
            puts "Error: #{e.message} with: #{klass_name}##{method_name}: #{exp_copy.inspect}"
            raise e
          end

    original = RubyToRuby.new.process(@original_tree.deep_clone)
    @reporter.replacing(klass_name, method_name, original, src) if @@debug

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

  def process_call(exp)
    recv = process(exp.shift)
    meth = exp.shift
    args = process(exp.shift)

    out = [:call, recv, meth]
    out << args if args

    stack = caller.map { |s| s[/process_\w+/] }.compact

    if stack.first != "process_iter" then
      mutate_node out
    else
      out
    end
  end

  ##
  # Replaces the call node with nil.

  def mutate_call(node)
    [:nil]
  end

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

  ##
  # So process_call works correctly

  def process_iter(exp)
    [:iter, process(exp.shift), process(exp.shift), process(exp.shift)]
  end

  def process_asgn(type, exp)
    var = exp.shift
    if exp.empty? then
      mutate_node [type, var]
    else
      mutate_node [type, var, process(exp.shift)]
    end
  end

  def mutate_asgn(node)
    type = node.shift
    var = node.shift
    if node.empty? then
      [:lasgn, :_heckle_dummy]
    else
      if node.last.first == :nil then
        [type, var, [:lit, 42]]
      else
        [type, var, [:nil]]
      end
    end
  end

  def process_cvasgn(exp)
    process_asgn :cvasgn, exp
  end

  ##
  # Replaces the value of the cvasgn with nil if its some value, and 42 if its
  # nil.

  alias mutate_cvasgn mutate_asgn

  def process_dasgn(exp)
    process_asgn :dasgn, exp
  end

  ##
  # Replaces the value of the dasgn with nil if its some value, and 42 if its
  # nil.

  alias mutate_dasgn mutate_asgn

  def process_dasgn_curr(exp)
    process_asgn :dasgn_curr, exp
  end

  ##
  # Replaces the value of the dasgn_curr with nil if its some value, and 42 if
  # its nil.

  alias mutate_dasgn_curr mutate_asgn

  def process_iasgn(exp)
    process_asgn :iasgn, exp
  end

  ##
  # Replaces the value of the iasgn with nil if its some value, and 42 if its
  # nil.

  alias mutate_iasgn mutate_asgn

  def process_gasgn(exp)
    process_asgn :gasgn, exp
  end

  ##
  # Replaces the value of the gasgn with nil if its some value, and 42 if its
  # nil.

  alias mutate_gasgn mutate_asgn

  def process_lasgn(exp)
    process_asgn :lasgn, exp
  end

  ##
  # Replaces the value of the lasgn with nil if its some value, and 42 if its
  # nil.

  alias mutate_lasgn mutate_asgn

  def process_lit(exp)
    mutate_node [:lit, exp.shift]
  end

  ##
  # Replaces the value of the :lit node with a random value.

  def mutate_lit(exp)
    case exp[1]
    when Fixnum, Float, Bignum
      [:lit, exp[1] + rand_number]
    when Symbol
      [:lit, rand_symbol]
    when Regexp
      [:lit, Regexp.new(Regexp.escape(rand_string.gsub(/\//, '\\/')))]
    when Range
      [:lit, rand_range]
    end
  end

  def process_str(exp)
    mutate_node [:str, exp.shift]
  end

  ##
  # Replaces the value of the :str node with a random value.

  def mutate_str(node)
    [:str, rand_string]
  end

  def process_if(exp)
    mutate_node [:if, process(exp.shift), process(exp.shift), process(exp.shift)]
  end

  ##
  # Swaps the then and else parts of the :if node.

  def mutate_if(node)
    [:if, node[1], node[3], node[2]]
  end

  def process_true(exp)
    mutate_node [:true]
  end

  ##
  # Swaps for a :false node.

  def mutate_true(node)
    [:false]
  end

  def process_false(exp)
    mutate_node [:false]
  end

  ##
  # Swaps for a :true node.

  def mutate_false(node)
    [:true]
  end

  def process_while(exp)
    cond, body, head_controlled = grab_conditional_loop_parts(exp)
    mutate_node [:while, cond, body, head_controlled]
  end

  ##
  # Swaps for a :until node.

  def mutate_while(node)
    [:until, node[1], node[2], node[3]]
  end

  def process_until(exp)
    cond, body, head_controlled = grab_conditional_loop_parts(exp)
    mutate_node [:until, cond, body, head_controlled]
  end

  ##
  # Swaps for a :while node.

  def mutate_until(node)
    [:while, node[1], node[2], node[3]]
  end

  def mutate_node(node)
    raise UnsupportedNodeError unless respond_to? "mutate_#{node.first}"
    increment_node_count node

    if should_heckle? node then
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
    if @mutatable_nodes.include? node.first
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

  ##
  # Returns a random Fixnum.

  def rand_number
    (rand(100) + 1)*((-1)**rand(2))
  end

  ##
  # Returns a random String

  def rand_string
    size = rand(50)
    str = ""
    size.times { str << rand(126).chr }
    str
  end

  ##
  # Returns a random Symbol

  def rand_symbol
    letters = ('a'..'z').to_a + ('A'..'Z').to_a
    str = ""
    (rand(50) + 1).times { str << letters[rand(letters.size)] }
    :"#{str}"
  end

  ##
  # Returns a random Range

  def rand_range
    min = rand(50)
    max = min + rand(50)
    min..max
  end

  ##
  # Suppresses output on $stdout and $stderr.

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
      puts "!" * 70
      puts "!!! #{message}"
      puts "!" * 70
      puts
    end

    def info(message)
      puts "*"*70
      puts "***  #{message}"
      puts "*"*70
      puts
    end

    def no_failures
      puts
      puts "The following mutations didn't cause test failures:"
      puts
    end

    def diff(original, mutation)
      length = [original.split(/\n/).size, mutation.split(/\n/).size].max

      Tempfile.open("orig") do |a|
        a.puts(original)
        a.flush

        Tempfile.open("fail") do |b|
          b.puts(mutation)
          b.flush

          diff_flags = " "

          output = `#{Heckle::DIFF} -U #{length} --label original #{a.path} --label mutation #{b.path}`
          puts output.sub(/^@@.*?\n/, '')
          puts
        end
      end
    end

    def failure(original, failure)
      self.diff original, failure
    end

    def no_surviving_mutants
      puts "No mutants survived. Cool!\n\n"
    end

    def replacing(klass_name, method_name, original, src)
      puts "Replacing #{klass_name}##{method_name} with:\n\n"
      diff(original, src)
    end

    def report_test_failures
      puts "Tests failed -- this is good"
    end
  end

  ##
  # All nodes that can be mutated by Heckle.

  MUTATABLE_NODES = instance_methods.grep(/mutate_/).sort.map do |meth|
    meth.sub(/mutate_/, '').intern
  end - [:asgn, :node] # Ignore these methods

  ##
  # All assignment nodes that can be mutated by Heckle..

  ASGN_NODES = MUTATABLE_NODES.map { |n| n.to_s }.grep(/asgn/).map do |n|
    n.intern
  end

end
