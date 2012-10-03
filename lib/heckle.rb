require 'rubygems'
require 'ruby_parser'
require 'sexp_processor'
require 'ruby2ruby'
require 'timeout'
require 'tempfile'

class String # :nodoc:
  def to_class
    split(/::/).inject(Object) { |klass, name| klass.const_get(name) }
  end
end

class Sexp
  # REFACTOR: move to sexp.rb
  def each_sexp
    self.each do |sexp|
      next unless Sexp === sexp

      yield sexp
    end
  end
end

##
# Test Unit Sadism

class Heckle < SexpProcessor

  class Timeout < Timeout::Error; end

  ##
  # The version of Heckle you are using.

  VERSION = '2.0.0.b1'

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

  def self.debug
    @@debug
  end

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
    self.expected = Sexp

    @mutatees = Hash.new
    @mutation_count = Hash.new 0
    @node_count = Hash.new 0
    @count = 0

    @mutatable_nodes = nodes
    @mutatable_nodes.each {|type| @mutatees[type] = [] }

    @failures = []

    @mutated = false

    @original_tree = rewrite find_scope_and_method
    @current_tree = @original_tree.deep_clone

    grab_mutatees

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
    left = mutations_left

    if left == 0 then
      @reporter.no_mutations(method_name)
      return
    end

    @reporter.method_loaded(klass_name, method_name, left)

    until left == 0 do
      @reporter.remaining_mutations left
      reset_tree
      begin
        process current_tree
        timeout(@@timeout, Heckle::Timeout) { run_tests }
      rescue SyntaxError => e
        @reporter.warning "Mutation caused a syntax error:\n\n#{e.message}}"
      rescue Heckle::Timeout
        @reporter.warning "Your tests timed out. Heckle may have caused an infinite loop."
      rescue Interrupt
        @reporter.warning 'Mutation canceled, hit ^C again to exit'
        sleep 2
      end

      left = mutations_left
    end

    reset # in case we're validating again. we should clean up.

    unless @failures.empty?
      @reporter.no_failures
      @failures.each do |failure|
        original = Ruby2Ruby.new.process(@original_tree.deep_clone)
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
    @current_tree = exp.deep_clone
    src = begin
            Ruby2Ruby.new.process(exp)
          rescue => e
            puts "Error: #{e.message} with: #{klass_name}##{method_name}: #{@current_tree.inspect}"
            raise e
          end

    if @@debug
      original = Ruby2Ruby.new.process(@original_tree.deep_clone)
      @reporter.replacing(klass_name, method_name, original, src)
    end

    self.count += 1

    clean_name = method_name.to_s.gsub(/self\./, '')
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

    mutate_node s(:call, recv, meth, args)
  end

  ##
  # Replaces the call node with nil.

  def mutate_call(node)
    s(:nil)
  end

  def process_defn(exp)
    self.method = exp.shift
    result = s(:defn, method)
    result << process(exp.shift) until exp.empty?
    heckle(result) if method == method_name

    return result
  ensure
    @mutated = false
    node_count.clear
  end

  def process_defs(exp)
    recv = process exp.shift
    meth = exp.shift

    self.method = "#{Ruby2Ruby.new.process(recv.deep_clone)}.#{meth}".intern

    result = s(:defs, recv, meth)
    result << process(exp.shift) until exp.empty?

    heckle(result) if method == method_name

    return result
  ensure
    @mutated = false
    node_count.clear
  end

  ##
  # So process_call works correctly

  def process_iter(exp)
    call = process exp.shift
    args = process exp.shift
    body = process exp.shift

    mutate_node s(:iter, call, args, body)
  end

  def mutate_iter(exp)
    s(:nil)
  end

  def process_asgn(type, exp)
    var = exp.shift
    if exp.empty? then
      mutate_node s(type, var)
    else
      mutate_node s(type, var, process(exp.shift))
    end
  end

  def mutate_asgn(node)
    type = node.shift
    var = node.shift
    if node.empty? then
      s(type, :_heckle_dummy)
    else
      if node.last.first == :nil then
        s(type, var, s(:lit, 42))
      else
        s(type, var, s(:nil))
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
    mutate_node s(:lit, exp.shift)
  end

  ##
  # Replaces the value of the :lit node with a random value.

  def mutate_lit(exp)
    case exp[1]
    when Fixnum, Float, Bignum
      s(:lit, exp[1] + rand_number)
    when Symbol
      s(:lit, rand_symbol)
    when Regexp
      s(:lit, Regexp.new(Regexp.escape(rand_string.gsub(/\//, '\\/'))))
    when Range
      s(:lit, rand_range)
    end
  end

  def process_str(exp)
    mutate_node s(:str, exp.shift)
  end

  ##
  # Replaces the value of the :str node with a random value.

  def mutate_str(node)
    s(:str, rand_string)
  end

  def process_if(exp)
    mutate_node s(:if, process(exp.shift), process(exp.shift), process(exp.shift))
  end

  ##
  # Swaps the then and else parts of the :if node.

  def mutate_if(node)
    s(:if, node[1], node[3], node[2])
  end

  def process_true(exp)
    mutate_node s(:true)
  end

  ##
  # Swaps for a :false node.

  def mutate_true(node)
    s(:false)
  end

  def process_false(exp)
    mutate_node s(:false)
  end

  ##
  # Swaps for a :true node.

  def mutate_false(node)
    s(:true)
  end

  def process_while(exp)
    cond, body, head_controlled = grab_conditional_loop_parts(exp)
    mutate_node s(:while, cond, body, head_controlled)
  end

  ##
  # Swaps for a :until node.

  def mutate_while(node)
    s(:until, node[1], node[2], node[3])
  end

  def process_until(exp)
    cond, body, head_controlled = grab_conditional_loop_parts(exp)
    mutate_node s(:until, cond, body, head_controlled)
  end

  ##
  # Swaps for a :while node.

  def mutate_until(node)
    s(:while, node[1], node[2], node[3])
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

  def walk_and_push(node, index = 0)
    return unless node.respond_to? :each
    return if node.is_a? String

    @walk_stack.push node.first
    node.each_with_index { |child_node, i| walk_and_push child_node, i }
    @walk_stack.pop

    if @mutatable_nodes.include? node.first and
       # HACK skip over call nodes that are the first child of an iter or
       # they'll get added twice
       #
       # I think heckle really needs two processors, one for finding and one
       # for heckling.
       !(node.first == :call and index == 1 and @walk_stack.last == :iter) then
      @mutatees[node.first].push(node)
    end
  end

  def grab_mutatees
    @walk_stack = []
    walk_and_push current_tree
  end

  def current_tree
    @current_tree.deep_clone
  end

  # Copied from Flay#process
  def find_scope_and_method
    expand_dirs_to_files.each do |file|
      #warn "Processing #{file}" if option[:verbose]

      ext = File.extname(file).sub(/^\./, '')
      ext = "rb" if ext.nil? || ext.empty?
      msg = "process_#{ext}"

      unless respond_to? msg then
        warn " Unknown file type: #{ext}, defaulting to ruby"
        msg = "process_rb"
      end

      begin
        sexp = begin
                 send msg, file
               rescue => e
                 warn " #{e.message.strip}"
                 warn " skipping #{file}"
                 nil
               end

        next unless sexp

        found = find_scope sexp

        return found if found
      rescue SyntaxError => e
        warn " skipping #{file}: #{e.message}"
      end
    end

    raise "Couldn't find method."
  end

  def process_rb file
    RubyParser.new.process(File.read(file), file)
  end

  def find_scope sexp, nesting=nil
    nesting ||= klass_name.split("::").map {|k| k.to_sym }
    current, *nesting = nesting

    sexp = s(:block, sexp) unless sexp.first == :block

    sexp.each_sexp do |node|
      next unless [:class, :module].include? node.first
      next unless node[1] == current

      block = node.detect {|s| Sexp === s && s[0] == :scope }[1]

      if nesting.empty?
        return sexp if method_name.nil?

        m = find_method block

        return m if m
      else
        s =  find_scope block, nesting

        return s if s
      end
    end

    nil
  end

  def find_method sexp
    class_method = method_name.to_s =~ /^self\./
    clean_name = method_name.to_s.sub(/^self\./, '').to_sym

    sexp = s(:block, sexp) unless sexp.first == :block

    sexp.each_sexp do |node|
      if class_method
        return node if node[0] == :defs && node[2] == clean_name
      else
        return node if node[0] == :defn && node[1] == clean_name
      end
    end

    nil
  end

  def expand_dirs_to_files(dirs='.')
    Array(dirs).flatten.map { |p|
      if File.directory? p then
        Dir[File.join(p, '**', "*.rb")]
      else
        p
      end
    }.flatten
  end

  def reset
    reset_tree
    reset_mutatees
    mutation_count.clear
  end

  def reset_tree
    return unless original_tree != current_tree
    @mutated = false

    @current_tree = original_tree.deep_clone

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

  def increment_node_count(node)
    node_count[node] += 1
  end

  def increment_mutation_count(node)
    # So we don't re-mutate this later if the tree is reset
    mutation_count[node] += 1
    mutatee_type = @mutatees[node.first]
    mutatee_type.delete_at mutatee_type.index(node)
    @mutated = true
  end

  ############################################################
  ### Convenience methods

  def aliasing_class(method_name)
    method_name.to_s =~ /self\./ ? class << @klass; self; end : @klass
  end

  def should_heckle?(exp)
    return false unless method == method_name
    return false if node_count[exp] <= mutation_count[exp]
    key = exp.first.to_sym

    mutatees.include?(key) && mutatees[key].include?(exp) && !already_mutated?
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
    @last_mutations_left ||= -1

    sum = 0
    @mutatees.each { |mut| sum += mut.last.size }

    if sum == @last_mutations_left then
      puts 'bug!'
      puts
      require 'pp'
      puts 'mutatees:'
      pp @mutatees
      puts
      puts 'original tree:'
      pp @original_tree
      puts
      puts "Infinite loop detected!"
      puts "Please save this output to an attachment and submit a ticket here:"
      puts "http://rubyforge.org/tracker/?func=add&group_id=1513&atid=5921"
      exit 1
    else
      @last_mutations_left = sum
    end

    sum
  end

  def current_code
    Ruby2Ruby.new.process current_tree
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
    return yield if @@debug

    begin
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
      puts "Tests failed -- this is good" if Heckle.debug
    end
  end

  ##
  # All nodes that can be mutated by Heckle.

  MUTATABLE_NODES = instance_methods.grep(/mutate_/).sort.map do |meth|
    meth.to_s.sub(/mutate_/, '').intern
  end - [:asgn, :node] # Ignore these methods

  ##
  # All assignment nodes that can be mutated by Heckle..

  ASGN_NODES = MUTATABLE_NODES.map { |n| n.to_s }.grep(/asgn/).map do |n|
    n.intern
  end

end

