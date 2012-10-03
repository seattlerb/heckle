# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.add_include_dirs("../../RubyInline/dev/lib",
                     "../../ruby2ruby/1.3.1/lib",
                     "../../ZenTest/dev/lib",
                     "../../sexp_processor/dev/lib",
                     "../../ruby_parser/2.3.1/lib",
                     "lib")

Hoe.plugin :seattlerb

Hoe.spec 'heckle' do
  developer 'Ryan Davis',   'ryand-ruby@zenspider.com'
  developer 'Pete Higgins', 'pete@peterhiggins.org'
  # developer 'Eric Hodel',  'drbrain@segment7.net'
  # developer 'Kevin Clark', 'kevin.clark@gmail.com'

  clean_globs << File.expand_path("~/.ruby_inline")

  dependency 'ruby_parser', '~> 2.3.1'
  dependency 'ruby2ruby', '~> 1.3.0'
  dependency 'ZenTest',   '~> 4.7.0'

  self.test_globs = ["test/test_*.rb"]
end

# vim: syntax=ruby
