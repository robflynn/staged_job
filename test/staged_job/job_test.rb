require "test_helper"

class JobTest < ActiveJob::TestCase
  def setup
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.logger.level = Logger::UNKNOWN # Silences the logger
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
    test_job_instance = TestJob.new
    assert_respond_to test_job_instance, :perform_stage_first_stage
    assert_respond_to test_job_instance, :perform_stage_second_stage
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

  context "lifecycle hooks" do

    it "allows for specifying before and after hooks for stages" do
      class FooJob < StagedJob::Job
        stage :first do
        end

        before_stage :first
        after_stage :first
        after_stage :first
      end

      assert_respond_to FooJob, :before_stage
      assert_respond_to FooJob, :after_stage

      assert_equal 1, FooJob.before_stage_procs.size
      assert_equal 2, FooJob.after_stage_procs.size
    end

    it "fires before and after lifecycle events around the stage" do
      class HookJob < StagedJob::Job
        stage :first_stage

        before_stage :first_stage, :my_before_hook
        after_stage :first_stage, :my_after_hook

        def my_before_hook; end
        def my_after_hook; end
      end

      sequence = sequence('hooks')

      job = HookJob.new
      job.expects(:my_before_hook).in_sequence(sequence)
      job.expects(:perform_stage).in_sequence(sequence)
      job.expects(:my_after_hook).in_sequence(sequence)

      job.perform
    end
  end # context "lifecycle hooks"
end
