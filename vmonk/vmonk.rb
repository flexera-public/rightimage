require 'rubygems'
require 'trollop'
require 'rest_connection'
require File.dirname(__FILE__) + '/lib/deployment_monk'
require 'ruby-debug'

dm = DeploymentMonk.new([27418,27418])
dm.generate_variations
debugger
puts 'blah'
