require 'rubygems'
require 'ruby_parser'
require 'sexp_processor'
require 'ruby2ruby'
require 'timeout'
require 'tempfile'

##
# Test Unit Sadism

module Heckle

  class Timeout < Timeout::Error; end

  ##
  # The version of Heckle you are using.

  VERSION = '2.0.0-beta'
end

require 'heckle/heckler'
