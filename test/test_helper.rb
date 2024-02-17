ENV["RAILS_ENV"] ||= "test"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "staged_job"

require "minitest/autorun"
require "minitest/reporters"
require 'mocha/minitest'
require 'active_job'

ActiveJob::Base.queue_adapter = :test
Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new(color: true)

class ParameterJob < StagedJob::Job
  params :number, :exponent
  async false

  stage :calculate_number do
    params[:number] ** params[:exponent]
  end

  stage :hexify do
    output[:calculate_number].to_s(16)
  end
end

class AsyncParameterJob < StagedJob::Job
  params :number, :exponent

  stage :calculate_number do
    params[:number] ** params[:exponent]
  end

  stage :hexify do
    output[:calculate_number].to_s(16)
  end
end

class SynchronousJob < StagedJob::Job
  async false

  stage :first_stage do
    42
  end

  stage :second_stage do
    output[:first_stage] + 1
  end

  stage :third_stage do
    output[:second_stage] * 2
  end
end

class FinishJob < StagedJob::Job
  stage :first_stage do
  end

  stage :second_stage do
  end
end

class TestJob < StagedJob::Job
  stage :first_stage do
    42
  end

  stage :second_stage do
    output[:first_stage] + 1
  end

  before_stage :first_stage do
  end

  after_stage :first_stage do
  end
end

class FailingJob < StagedJob::Job
  stage :first_stage do
      raise "This stage should not complete."
  end

  stage :second_stage do
  end

  stage :third_stage do
    43
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

    def context(description, &block)
      block.call
    end
  end
end