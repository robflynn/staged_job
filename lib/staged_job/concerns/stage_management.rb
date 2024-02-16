require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

module StagedJob
  class NoStagesError < StandardError; end

  module Concerns
    module StageManagement
      extend ActiveSupport::Concern

      included do
        class_attribute :stages, instance_writer: false, default: []

        # Note: We're keeping before_stage_procs an array because
        # we want hooks to be executed in the order they were defined.
        class_attribute :before_stage_procs, instance_writer: false, default: []
        class_attribute :after_stage_procs, instance_writer: false, default: []

        attr_accessor :current_stage, :params

        # If we don't duplicate the stages, then the stages will be
        # shared between all subclasses.
        def self.inherited(subclass)
          super

          subclass.stages = stages.dup
          subclass.before_stage_procs = before_stage_procs.dup
          subclass.after_stage_procs = after_stage_procs.dup
        end

        def perform(stage: nil, **args)
          if self.class.stages.empty?
            raise StagedJob::NoStagesError, "No stages defined for #{self.class.name}"
          end

          stage ||= stages.first
          self.current_stage = stage
          self.params = args

          self.class.call_stage_procs(self, current_stage, self.class.before_stage_procs)
          perform_stage(stage, **args)
          self.class.call_stage_procs(self, current_stage, self.class.after_stage_procs)
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

      class_methods do
        def stage(stage_name, &block)
          stages << stage_name

          method_name = "perform_stage_#{stage_name}"

          build_stage_method(method_name, &block)
        end

        def before_stage(stage = nil, method_name = nil, &block)
          before_stage_procs << { stage: stage, method: method_name, block: block }
        end

        def after_stage(stage = nil, method_name = nil,  &block)
          after_stage_procs << { stage: stage, method: method_name, block: block }
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

        private

        def build_stage_method(method_name, &block)
          define_method(method_name) do |**args|

            instance_exec(**args, &block)

            unless last_stage?
              transition_to(next_stage)
            else
              # TODO: Handle done condition
            end
          end
        end
      end
    end
  end
end