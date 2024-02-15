$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "staged_job"

require "minitest/autorun"
require 'active_job'

ActiveJob::Base.queue_adapter = :test

class TestJob < StagedJob::Job
  stage :first_stage do
  end

  stage :second_stage do
  end
end
