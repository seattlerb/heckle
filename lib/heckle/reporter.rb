module Heckle
  class Reporter
    def no_mutations(method_name)
      puts
      puts "!"*70
      puts "!!! #{method_name} has a thick skin. There's nothing to heckle."
      puts "!"*70
      puts
    end

    def method_loaded(klass_name, method_name, mutations_left)
      puts
      puts "*"*70
      puts "***  #{klass_name}\##{method_name} loaded with #{mutations_left} possible mutations"
      puts "*"*70
      puts
    end

    def remaining_mutations(mutations_left)
      puts "#{mutations_left} mutations remaining..."
    end

    def no_failures
      puts "\nThe following mutations didn't cause test failures:\n"
    end

    def failure(failure)
      puts "\n#{failure}\n"
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
