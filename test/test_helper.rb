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

def deep_symbolize_keys(obj)
  case obj
  when Hash
    obj.each_with_object({}) do |(key, value), result|
      result[key.to_sym] = deep_symbolize_keys(value)
    end
  when Array
    obj.map { |e| deep_symbolize_keys(e) }
  else
    obj
  end
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

  def assert_enqueued_with_partial_args(job:, args:, &block)
    assert_enqueued_with(job: job, &block)

    enqueued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j["job_class"] == job.to_s }
    assert_not_nil enqueued_job, "Expected #{job} to be enqueued"

    enqueued_args = ActiveJob::Arguments.deserialize(enqueued_job["arguments"]).first
    expected_args = deep_symbolize_keys(args).first

    actual_args = enqueued_args.slice(*expected_args.keys)

    assert_equal expected_args, actual_args, "Expected arguments #{expected_args} do not match actual arguments #{actual_args}"
  end
end