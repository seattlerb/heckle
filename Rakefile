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

require './lib/heckle.rb'

Hoe.new('heckle', Heckle::VERSION) do |heckle|
  heckle.rubyforge_name = 'seattlerb'

  heckle.developer('Ryan Davis', 'ryand-ruby@zenspider.com')
  heckle.developer('Eric Hodel', 'drbrain@segment7.net')
  heckle.developer('Kevin Clark', 'kevin.clark@gmail.com')

  heckle.clean_globs << File.expand_path("~/.ruby_inline")

  heckle.extra_deps << ['ParseTree', '>= 2.0.0']
  heckle.extra_deps << ['ruby2ruby', '>= 1.1.6']
  heckle.extra_deps << ['ZenTest', '>= 3.5.2']
end

# vim: syntax=Ruby
