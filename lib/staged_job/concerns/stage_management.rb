require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

module StagedJob
  module Concerns
    module StageManagement
      extend ActiveSupport::Concern

      included do
        class_attribute :stages, default: []
      end

      class_methods do
        def stage(stage_name, &block)
          stages << stage_name

          method_name = "perform_stage_#{stage_name}"

          puts method_name

          build_stage_method(method_name, &block)
        end

        private

        def build_stage_method(method_name, &block)
          define_method(method_name) do |**args|
            instance_exec(**args, &block)
          end
        end
      end
    end
  end
end