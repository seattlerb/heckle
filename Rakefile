# -*- ruby -*-

$: << 'lib'

require 'rubygems'
require 'hoe'

deps = %w(ParseTree RubyInline ruby2ruby ZenTest)
$:.push(*deps.map { |p| "../../#{p}/dev/lib" })

require './lib/heckle.rb'

Hoe.new('heckle', Heckle::VERSION) do |p|
  p.rubyforge_name = 'seattlerb'
  p.author = ['Ryan Davis', 'Kevin Clark', 'Eric Hodel']
  p.summary = 'Unit Test Sadism'
  p.description = p.paragraphs_of('README.txt', 2).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")

  p.extra_deps << ['ParseTree', '~> 2']
  p.extra_deps << ['ruby2ruby', '>= 1.1.6']
  p.extra_deps << ['ZenTest', '>= 3.5.2']
end

Hoe::RUBY_FLAGS.sub! /-I/, "-I#{deps.map { |p| "../../#{p}/dev/lib" }.join(":")}:"

# vim: syntax=Ruby
