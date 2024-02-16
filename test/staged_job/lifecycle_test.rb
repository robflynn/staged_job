require "test_helper"

class LifecycleTest < ActiveJob::TestCase
  def setup
    @lifecycle = StagedJob::Lifecycle.new
    @context = { stage: :test_stage, job: mock }
  end

  it "allows for adding hooks" do
    @lifecycle.before_start {}

    assert_equal 1, @lifecycle.callbacks[:before_start].size
  end

  it "calls hooks with matching stages" do
    method_name = :custom_callback_method
    @lifecycle.before_stage(:test_stage, method_name)
    @context[:job].expects(method_name).once
    @lifecycle.call_callbacks(:before_stage, @context)
  end

  it "does not call hooks if stage does not match" do
    method_name = :custom_callback_method
    @lifecycle.before_stage(:another_stage, method_name)
    @context[:job].expects(method_name).never
    @lifecycle.call_callbacks(:before_stage, @context)
  end

  it "calls hooks without provided stages" do
    block_called = false
    @lifecycle.before_start { block_called = true }
    @lifecycle.call_callbacks(:before_start, @context)
    assert block_called
  end

  it "calls block hooks with provided stages" do
    block_called = false
    @lifecycle.before_stage(:test_stage) { block_called = true }
    @lifecycle.call_callbacks(:before_stage, @context)
    assert block_called
  end

  it "calls hooks in the order they were added" do
    sequence = sequence('hook_sequence')

    @lifecycle.before_start :first_hook
    @lifecycle.before_start :second_hook

    @context[:job].expects(:first_hook).in_sequence(sequence).once
    @context[:job].expects(:second_hook).in_sequence(sequence).once

    @lifecycle.call_callbacks(:before_start, @context)
  end
end

