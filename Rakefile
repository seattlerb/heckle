# -*- ruby -*-

$: << 'lib'

require 'rubygems'
require 'hoe'
require './lib/heckle.rb'

Hoe.new('heckle', Heckle::VERSION) do |p|
  p.rubyforge_name = 'seattlerb'
  p.summary = 'Unit Test Sadism'
  p.description = p.paragraphs_of('README.txt', 2).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")

  p.extra_deps << ['ruby2ruby', '>= 1.1.0']
  p.extra_deps << ['ZenTest', '>= 3.5.2']
  
end

# vim: syntax=Ruby
