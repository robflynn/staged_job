module StagedJob
  class Lifecycle
    EVENTS = {
      before_start: [],
      before_stage: [],
      after_stage: [],
      after_finish: [],
      on_error: []
    }

    attr_reader :callbacks

    def initialize
      @callbacks = EVENTS.keys.each_with_object({}) do |event, hash|
        hash[event] = []
      end
    end

    def before_start(method_name = nil, &block)
      add_callback(:before_start, method_name, block)
    end

    def after_finish(method_name = nil, &block)
      add_callback(:after_finish, method_name, block)
    end

    def before_stage(stage = nil, method_name = nil, &block)
      add_callback(:before_stage, method_name, block, stage)
    end

    def after_stage(stage = nil, method_name = nil, &block)
      add_callback(:after_stage, method_name, block, stage)
    end

    def on_error(method_name = nil, &block)
      add_callback(:on_error, method_name, block)
    end

    def call_callbacks(event, context, *args)
      # TODO: Do we need to handle missing / invalid callbacks here?

      @callbacks[event].each do |callback|
        next if callback[:stage] && callback[:stage] != context[:stage]

        if callback[:method]
          context[:job].send(callback[:method])
        else
          callback[:block].call(*args)
        end
      end
    end

  private

    def add_callback(event, method_name, block, stage = nil)
      @callbacks[event] << { method: method_name, block: block, stage: stage }
    end
  end
end