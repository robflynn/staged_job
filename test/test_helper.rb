ENV["RAILS_ENV"] ||= "test"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "staged_job"

require "minitest/autorun"
require "minitest/reporters"
require 'mocha/minitest'
require 'active_job'

ActiveJob::Base.queue_adapter = :test
Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new(color: true)

class TestJob < StagedJob::Job
  stage :first_stage do
    43 + 43
  end

  stage :second_stage do
  end
end

class FailingJob < StagedJob::Job
  stage :first_stage do
    return true
  end

  stage :second_stage do
    raise "This stage should not complete."
  end

  stage :third_stage do
    return 43
  end
end

class EmptyJob < StagedJob::Job
end

module StagedJobHelpers
  include ActiveJob::TestHelper
end

class ActiveSupport::TestCase
  include StagedJobHelpers

  class << self
    def it(description, &block)
      test(description, &block)
    end
  end
end