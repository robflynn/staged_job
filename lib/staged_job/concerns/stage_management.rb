require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

module StagedJob
  class NoStagesError < StandardError; end

  module Concerns
    module StageManagement
      extend ActiveSupport::Concern

      included do
        class_attribute :stages, instance_writer: false, default: []

        attr_accessor :current_stage, :params

        # If we don't duplicate the stages, then the stages will be
        # shared between all subclasses.
        def self.inherited(subclass)
          super

          subclass.stages = stages.dup
        end

        def perform(stage: nil, **args)
          if self.class.stages.empty?
            raise StagedJob::NoStagesError, "No stages defined for #{self.class.name}"
          end

          stage ||= stages.first
          self.current_stage = stage
          self.params = args

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

        private

        def build_stage_method(method_name, &block)
          define_method(method_name) do |**args|
            # TODO: Fire before_stage
            instance_exec(**args, &block)
            # TODO: Fire after_stage

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