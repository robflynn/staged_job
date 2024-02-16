require "test_helper"

class IntegrationTest < ActiveJob::TestCase
  setup do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.logger.level = Logger::UNKNOWN # Silences the logger
  end

  teardown do
    ActiveJob::Base.logger.level = Logger::DEBUG # Resets logger level
  end

  context "Lifecycle Hook Integration" do
    context "before and after" do
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

        job = FooJob.new
        assert_equal 1, job.lifecycle_manager.callbacks[:before_stage].size
        assert_equal 2, job.lifecycle_manager.callbacks[:after_stage].size
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
    end # end context "before and after hooks"


    context "start and finish" do
      class StartFinishJob < StagedJob::Job
        stage :first_stage do
        end

        stage :second_stage do
        end

        before_start :my_before_start_hook
        after_finish :my_after_finish_hook

        before_stage :first_stage, :my_before_stage_hook
        after_stage :second_stage, :my_after_stage_hook

        def my_before_start_hook;end
        def my_after_finish_hook;end
        def my_before_stage_hook;end
        def my_after_stage_hook;end
      end

      it "should allow for defining start and finish hooks" do
        assert_respond_to TestJob, :before_start
        assert_respond_to TestJob, :after_finish
      end

      it "should fire before_start and after_finish hooks" do
        sequence = sequence('hooks')

        job = StartFinishJob.new
        job.expects(:my_before_start_hook).in_sequence(sequence)
        job.expects(:perform_stage).with(:first_stage).in_sequence(sequence)
        job.expects(:perform_stage).with(:second_stage).in_sequence(sequence)
        job.expects(:my_after_finish_hook).in_sequence(sequence)

        job.perform(stage: :first_stage)
        job.perform(stage: :second_stage)
      end

      it "fires before stage after starting and after stage before finishing" do
        job = StartFinishJob.new

        sequence = sequence('hooks')
        job.expects(:my_before_start_hook).in_sequence(sequence)
        job.expects(:my_before_stage_hook).in_sequence(sequence)
        job.expects(:my_after_stage_hook).in_sequence(sequence)
        job.expects(:my_after_finish_hook).in_sequence(sequence)

        job.perform(stage: :first_stage)
        job.perform(stage: :second_stage)
      end
    end
  end # end context "Lifecycle Hook Integration"

  context "Error Handling" do
    context "error handling" do
      class ErrorJob < StagedJob::Job
        stage :first_stage do
          raise "This stage should not complete."
        end

        on_error :my_error_hook
        def my_error_hook(e); end
      end

      it "allows for defining error hooks" do
        assert_respond_to ErrorJob, :on_error
        assert_equal 1, ErrorJob.lifecycle_manager.callbacks[:on_error].size
      end

      it "it fires on_error hooks when a stage fails" do
        job = ErrorJob.new
        job.expects(:my_error_hook).once
        job.perform

        assert_equal :failed, job.status
        assert job.failed?
      end

      it "raises errors if no on_error is given" do
        assert_raises StandardError do
          FailingJob.perform_now
        end
      end
    end # context "error handling"
  end
end