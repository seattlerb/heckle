# -*- ruby -*-

$: << 'lib'

require 'rubygems'
require 'hoe'

deps = %w(ParseTree RubyInline ruby2ruby ZenTest)
$:.push(*deps.map { |p| "../../#{p}/dev/lib" })

require './lib/heckle.rb'

Hoe.new('heckle', Heckle::VERSION) do |heckle|
  heckle.rubyforge_name = 'seattlerb'

  heckle.developer('Ryan Davis', 'ryand-ruby@zenspider.com')
  heckle.developer('Eric Hodel', 'drbrain@segment7.net')
  heckle.developer('Kevin Clark', 'kevin.clark@gmail.com')

  heckle.clean_globs << File.expand_path("~/.ruby_inline")

  heckle.extra_deps << ['ParseTree', '~> 2']
  heckle.extra_deps << ['ruby2ruby', '>= 1.1.6']
  heckle.extra_deps << ['ZenTest', '>= 3.5.2']
end

Hoe::RUBY_FLAGS.sub! /-I/, "-I#{deps.map { |p| "../../#{p}/dev/lib" }.join(":")}:"

# vim: syntax=Ruby
