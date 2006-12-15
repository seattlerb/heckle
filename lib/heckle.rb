require 'rubygems'
require 'parse_tree'
require 'ruby2ruby'
require 'logger'

class String
  def to_class
    split(/::/).inject(Object) { |klass, name| klass.const_get(name) }
  end
end

class Heckle < SexpProcessor
  VERSION = '1.0.0'
    
  MUTATABLE_NODES = [:if, :lit, :str, :true, :false, :while, :until]

  attr_accessor :file, :klass_name, :method_name, :klass, :method, :mutatees, :original_tree,
                :mutation_count, :node_count, :failures
  
  @@debug = false;
  
  def self.debug=(value)
    @@debug = value
  end
  
  def self.validate(klass_name)
    klass_name.to_class.instance_methods(false).each do |meth|
      heckler = self.new(klass_name, meth)
      heckler.validate
    end
  end
  
  def initialize(klass_name=nil, method_name=nil)
    super()

    @klass_name, @method_name = klass_name, method_name.intern
    @klass = @method = nil
    
    load_test_files
            
    self.strict = false
    self.auto_shift_type = true
    self.expected = Array
    
    @mutatees = Hash.new
    @mutation_count = Hash.new
    @node_count = Hash.new
    
    MUTATABLE_NODES.each {|type| @mutatees[type] = [] }
    
    @failures = []
    
    @mutated = false

    grab_mutatees
    
    @original_tree = current_tree.deep_clone
    @original_mutatees = mutatees.deep_clone
  end
  
  ############################################################
  ### Overwrite test_pass?, load_test_files for your own Heckle runner.
  def tests_pass?
    raise NotImplementedError
  end

  def run_tests
    if tests_pass? then
      record_passing_mutation
    else
      report_test_failures
    end
  end
  
  def load_test_files
    Dir.glob(ENV['TESTS'] || 'test/test_*.rb').each {|test| require test}
  end

  ############################################################
  ### Running the script
  
  def validate
    puts "Validating #{file}"
    if tests_pass? then
      puts "Tests passed -- heckling"
      
      until @mutatees.collect {|k,v| v}.uniq.flatten.empty?
        reset_tree if current_tree != original_tree
        process current_tree
        silence_stream(STDOUT) { run_tests }
      end
      
      unless @failures.empty?
        puts "The following mutations didn't cause test failures:\n"
        @failures.each {|failure| puts "\n#{failure}\n"}
      else
        puts "No mutants survived. Cool!"
      end
    else
      puts "Tests failed... fix and run heckle again"
    end
  end

  def record_passing_mutation
    @failures << current_code
  end
  
  def heckle(exp)
    puts "\nHeckling #{klass_name}##{method_name}\n" if @@debug
    src = RubyToRuby.new.process(exp)
    puts "Replacing #{klass_name}##{method_name} with:\n\n#{src}\n" if @@debug
    klass_name.to_class.class_eval(src)
  end  
  
  ############################################################
  ### Processing sexps
  
  def process_defn(exp)    
    self.method = exp.shift
    result = [:defn, method]
    result << process(exp.shift) until exp.empty?
    heckle(result) if method == method_name
    @mutated = false
    reset_node_count

    return result
  end
  
  def process_lit(exp)
    mutate_node [:lit, exp.shift]
  end
  
  def mutate_lit(exp)
    case exp[1]
    when Fixnum, Float, Bignum
      [:lit, exp[1] + rand(10)]
    when Symbol
      [:lit, :"#{rand_string}"]
    when Regexp
      [:lit, /#{Regexp.escape(rand_string)}/]
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

    r2r = RubyToRuby.new
    src = r2r.process(original_tree.deep_clone)  
    klass_name.to_class.class_eval(src)
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
  
  def should_heckle?(exp)
    return false unless method == method_name
    mutation_count[exp] = 0 if mutation_count[exp].nil?
    return false if node_count[exp] <= mutation_count[exp]
    mutatees[exp.first.to_sym].include?(exp) && !already_mutated?
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
  
  def current_code
    RubyToRuby.translate(klass_name.to_class, method_name)
  end
  
  def rand_string
    size = rand(100)
    str = ""
    size.times { str << rand(126).chr }
    str
  end
  
  def rand_range
    min = rand(50)
    max = min + rand(50)
    min..max
  end
  
  def abort_and_report_incomplete_tests
    abort "*** Tests passed again after heckling, your tests are incomplete"
  end
  
  def report_test_failures
    puts "Tests failed -- this is good"
  end
  
  # silence_stream taken from Rails ActiveSupport reporting.rb
  
  # Silences any stream for the duration of the block.
  #
  #   silence_stream(STDOUT) do
  #     puts 'This will never be seen'
  #   end
  #
  #   puts 'But this will'
  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
  end

end
