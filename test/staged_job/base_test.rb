require "test_helper"

class BaseTest < ActiveJob::TestCase
  def setup
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.logger.level = Logger::UNKNOWN # Silences the logger
  end

  def teardown
    ActiveJob::Base.logger.level = Logger::DEBUG # Resets logger level or to whatever default you prefer
  end

  context "#stages" do
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
  end # end context "#stages"

  context "#params" do
    it "allows for defining params" do
      assert_respond_to ParameterJob, :params
      assert_respond_to ParameterJob.any_instance, :params
      assert_equal [:number, :exponent], ParameterJob.parameters
    end

    it "accepts valid params" do
      assert_nothing_raised do
        ParameterJob.perform_now(number: 2, exponent: 3)
      end
    end

    it "raises an error when invalid params are passed" do
      assert_raises(ArgumentError) do
        ParameterJob.perform_now(fish: 12)
      end
    end

    it "raises an error when required params are not passed" do
      assert_raises(ArgumentError) do
        ParameterJob.perform_now(exponent: 3)
      end
    end

    it "passes params to stages when requeing" do
      assert_enqueued_with(job: AsyncParameterJob, args: [{ stage: :hexify, number: 2, exponent: 3 }]) do
        AsyncParameterJob.perform_now(number: 2, exponent: 3)
      end
    end
  end # end context "#params"

  context "#status" do
    it "should have a pending status before the first stage" do
      job = TestJob.new
      assert job.pending?
    end

    it "should have a finished state after the last stage" do
      job = FinishJob.new
      job.perform(stage: :second_stage)
      assert job.finished?
    end
  end # end context "#status"

  it "provides stage output" do
    assert_respond_to TestJob.any_instance, :output

    job = TestJob.new
    job.perform(stage: :first_stage)
    job.perform(stage: :second_stage)

    assert_equal 42, job.output[:first_stage]
    assert_equal 43, job.output[:second_stage]
  end

  it "allows for synchronous jobs" do
    job = SynchronousJob.new
    job.perform_now

    assert job.finished?
    assert_equal 42, job.output[:first_stage]
    assert_equal 43, job.output[:second_stage]
    assert_equal 86, job.output[:third_stage]
  end
end

