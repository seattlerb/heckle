# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.add_include_dirs("../../ParseTree/dev/lib",
                     "../../ParseTree/dev/test",
                     "../../RubyInline/dev/lib",
                     "../../ruby2ruby/dev/lib",
                     "../../ZenTest/dev/lib",
                     "../../sexp_processor/dev/lib",
                     "lib")

Hoe.plugin :seattlerb

Hoe.spec 'heckle' do
  developer 'Ryan Davis', 'ryand-ruby@zenspider.com'
  developer 'Eric Hodel', 'drbrain@segment7.net'
  developer 'Kevin Clark', 'kevin.clark@gmail.com'

  self.rubyforge_name = 'seattlerb'

  clean_globs    << File.expand_path("~/.ruby_inline")
  extra_deps     << ['ParseTree', '>= 2.0.0']
  extra_deps     << ['ruby2ruby', '1.2.2']
  extra_deps     << ['ZenTest', '>= 3.5.2']
  multiruby_skip << "1.9"
end

# vim: syntax=ruby
