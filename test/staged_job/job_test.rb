require "test_helper"

class JobTest < ActiveJob::TestCase
  def setup
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.logger.level = Logger::UNKNOWN # Silences the logger

    @test_job_instance = TestJob.new
  end

  def teardown
    ActiveJob::Base.logger.level = Logger::DEBUG # Resets logger level or to whatever default you prefer
  end

  it "It allows for defining stages" do
    assert_respond_to TestJob, :stage
    assert_respond_to TestJob, :stages

    assert_equal [:first_stage, :second_stage], TestJob.stages
  end

  it "responds to defined stages" do
    assert_respond_to @test_job_instance, :perform_stage_first_stage
    assert_respond_to @test_job_instance, :perform_stage_second_stage
  end

  it "it requires stages to exist before running" do
    assert_raises(StagedJob::NoStagesError) do
      EmptyJob.perform_now
    end
  end

  it "runs the first stage when calling perform" do
    TestJob.any_instance.expects(:perform_stage_first_stage).once
    TestJob.perform_now
  end

  it "should queue the second stage after running the first stage" do
    assert_enqueued_with(job: TestJob, args: [{ stage: :second_stage }]) do
      TestJob.perform_now
    end
  end
end
