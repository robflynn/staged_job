require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

module StagedJob
  class NoStagesError < StandardError; end

  module Concerns
    module StageManagement
      extend ActiveSupport::Concern

      module Status
        PENDING  = :pending
        RUNNING  = :running
        FINISHED = :finished
        FAILED   = :failed
      end

      included do
        class_attribute :stages, instance_writer: false, default: []

        # Note: We're keeping before_stage_procs an array because
        # we want hooks to be executed in the order they were defined.
        class_attribute :before_stage_procs, instance_writer: false, default: []
        class_attribute :after_stage_procs, instance_writer: false, default: []
        class_attribute :on_error_procs, instance_writer: false, default: []
        class_attribute :before_start_procs, instance_writer: false, default: []
        class_attribute :after_finish_procs, instance_writer: false, default: []

        attr_accessor :current_stage, :params, :status, :output

        # If we don't duplicate the stages, then the stages will be
        # shared between all subclasses.
        def self.inherited(subclass)
          super

          subclass.stages = stages.dup
          subclass.before_stage_procs = before_stage_procs.dup
          subclass.after_stage_procs = after_stage_procs.dup
          subclass.on_error_procs = on_error_procs.dup
          subclass.before_start_procs = before_start_procs.dup
          subclass.after_finish_procs = after_finish_procs.dup
        end

        def initialize(*args)
          super
          self.status = Status::PENDING
          self.output ||= {}
        end

        def pending?
          self.status == Status::PENDING
        end

        def finished?
          self.status == Status::FINISHED
        end

        def running?
          self.status == Status::RUNNING
        end

        def failed?
          self.status == Status::FAILED
        end

        def perform(stage: nil, **args)
          if self.class.stages.empty?
            raise StagedJob::NoStagesError, "No stages defined for #{self.class.name}"
          end

          stage ||= stages.first
          self.current_stage = stage
          self.params = args

          if pending?
            self.class.call_procs(self, self.class.before_start_procs)
          end

          self.status = Status::RUNNING

          self.class.call_stage_procs(self, current_stage, self.class.before_stage_procs)

          begin
            perform_stage(stage, **args)
          rescue => e
            self.class.call_procs(self, self.class.on_error_procs, e)
            self.status = Status::FAILED

            # If there's no on_error catcher, re-raise the exception
            if self.class.on_error_procs.empty?
              raise e
            end
          end

          # If hte job has failed, let's just exit early
          #
          # TODO: Determine what DelayedJob, et. al do with this
          # failed job. Do they requeue it themselves?  That's
          # probably okay, so long as we can re-adjust our status.
          if failed?
            return
          end

          self.class.call_stage_procs(self, current_stage, self.class.after_stage_procs)

          unless last_stage?
            transition_to(next_stage)
          else
            self.status = Status::FINISHED
            self.class.call_procs(self, self.class.after_finish_procs)
          end
        end

        def perform_stage(stage, **args)
          send("perform_stage_#{stage}", **args)
        end

        def transition_to(stage)
          requeue_or_run(stage)
        end

        def last_stage?
          stages.last == current_stage
        end

        def next_stage
          stages[stages.index(current_stage) + 1]
        end

        private

        def requeue_or_run(stage)
          self.class.set(wait: 1.seconds).perform_later(stage: stage, **params)
        end
      end

      ####################
      # CLASS METHODS
      ####################

      class_methods do
        def stage(stage_name, &block)
          stages << stage_name

          method_name = "perform_stage_#{stage_name}"

          build_stage_method(method_name, &block)
        end

        def before_start(method_name = nil, &block)
          before_start_procs << { method: method_name, block: block }
        end

        def after_finish(method_name = nil, &block)
          after_finish_procs << { method: method_name, block: block }
        end

        def before_stage(stage = nil, method_name = nil, &block)
          before_stage_procs << { stage: stage, method: method_name, block: block }
        end

        def after_stage(stage = nil, method_name = nil,  &block)
          after_stage_procs << { stage: stage, method: method_name, block: block }
        end

        def on_error(method_name = nil, &block)
          on_error_procs << { method: method_name, block: block }
        end

        def call_stage_procs(job, stage, procs)
          procs.each do |hook|
            next unless hook[:stage].nil? || hook[:stage] == stage

            if hook[:method]
              job.send(hook[:method])
            else
              hook[:block].call(stage)
            end
          end
        end

        def call_procs(job, procs, *args)
          procs.each do |hook|
            if hook[:method]
              job.send(hook[:method], *args)
            else
              hook[:block].call(*args)
            end
          end
        end

        private

        def build_stage_method(method_name, &block)
          define_method(method_name) do |**args|
            result = instance_exec(**args, &block)

            self.output[current_stage] = result
          end
        end # build_stage_method
      end # class_methods
    end # StageManagement
  end # Concerns
end  # StagedJob