require "test_helper"

class NewTestJob < StagedJob::Base
  stage :first_stage do
  end

  stage :second_stage do
  end
end

class NewEmptyJob < StagedJob::Base
end

class NewFailingJob < StagedJob::Base
  stage :first_stage do
    raise "This stage should not complete."
  end

  stage :second_stage do
  end

  stage :third_stage do
    43
  end
end

class BaseTest < ActiveJob::TestCase
  def setup
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.logger.level = Logger::UNKNOWN # Silences the logger
  end

  def teardown
    ActiveJob::Base.logger.level = Logger::DEBUG # Resets logger level or to whatever default you prefer
  end

  it "It allows for defining stages" do
    assert_respond_to NewTestJob, :stage
    assert_respond_to NewTestJob, :stages

    assert_equal [:first_stage, :second_stage], NewTestJob.stages
  end

  it "responds to defined stages" do
    test_job_instance = NewTestJob.new
    assert_respond_to test_job_instance, :perform_stage_first_stage
    assert_respond_to test_job_instance, :perform_stage_second_stage
  end

  it "it requires stages to exist before running" do
    assert_raises(StagedJob::NoStagesError) do
      NewEmptyJob.perform_now
    end
  end

  it "runs the first stage when calling perform" do
    NewTestJob.any_instance.expects(:perform_stage_first_stage).once
    NewTestJob.perform_now
  end

  it "should queue the second stage after running the first stage" do
    assert_enqueued_with(job: NewTestJob, args: [{ stage: :second_stage }]) do
      NewTestJob.perform_now
    end
  end

  it "should have a pending status before the first stage" do
    job = TestJob.new
    assert job.pending?
  end

  it "should have a finished state after the last stage" do
    class FinishJob < StagedJob::Base
      stage :first_stage do
      end

      stage :second_stage do
      end
    end

    job = FinishJob.new
    job.perform(stage: :second_stage)
    assert job.finished?
  end

  it "provide stage output" do
    assert_respond_to TestJob.any_instance, :output

    job = TestJob.new
    job.perform(stage: :first_stage)
    job.perform(stage: :second_stage)

    assert_equal 42, job.output[:first_stage]
    assert_equal 43, job.output[:second_stage]
  end

  it "allows for synchronous jobs" do
    class SynchronousJob < StagedJob::Base
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

    job = SynchronousJob.new
    job.perform_now

    assert job.finished?
    assert_equal 42, job.output[:first_stage]
    assert_equal 43, job.output[:second_stage]
    assert_equal 86, job.output[:third_stage]
  end
end

