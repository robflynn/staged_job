# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb'] # This pattern searches for all test files in the test directory.
  t.verbose = true
end

task default: %i[]

