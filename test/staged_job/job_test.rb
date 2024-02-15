require "test_helper"

describe StagedJob::Job do
  before do
    @test_job_instance = TestJob.new
  end

  it "It allows for defining stages" do
    _(TestJob).must_respond_to :stage
    _(TestJob).must_respond_to :stages

    _(TestJob.stages).must_equal [:first_stage, :second_stage]
  end

  it "responds to defined stages" do
    _(@test_job_instance).must_respond_to :perform_stage_first_stage
    _(@test_job_instance).must_respond_to :perform_stage_second_stage
  end
end