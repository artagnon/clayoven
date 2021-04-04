require 'simplecov'

SimpleCov.start do
  command_name 'minitest'
  enable_coverage :branch
  primary_coverage :branch
  enable_for_subprocesses true
end

require 'minitest/autorun'
