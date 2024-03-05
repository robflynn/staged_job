module StagedJob
  class NoStagesError < StandardError; end

  class Base < ActiveJob::Base
    include Status

    class_attribute :stages, instance_writer: false, default: []
    class_attribute :asynchronous, instance_writer: false, default: true
    class_attribute :lifecycle_manager, instance_writer: false
    class_attribute :parameters, instance_writer: false, default: []

    attr_accessor :current_stage, :status, :output, :params

    def self.inherited(subclass)
      super

      subclass.stages = stages.dup
      subclass.asynchronous = asynchronous.dup
      subclass.lifecycle_manager = Lifecycle.new
      subclass.parameters = parameters.dup
    end

    def initialize(*args, **kwargs)
      super

      self.status = Status::PENDING
      self.output ||= {}
    end

    def self.stage(name, &block)
      stages << name
      build_stage_method("perform_stage_#{name}", &block)
    end

    def self.params(*args)
      self.parameters = args
    end

    def self.before_stage(stage = nil, method_name = nil, &block)
      lifecycle_manager.before_stage(stage, method_name, &block)
    end

    def self.after_stage(stage = nil, method_name = nil, &block)
      lifecycle_manager.after_stage(stage, method_name, &block)
    end

    def self.before_start(method_name = nil, &block)
      lifecycle_manager.before_start(method_name, &block)
    end

    def self.after_finish(method_name = nil, &block)
      lifecycle_manager.after_finish(method_name, &block)
    end

    def self.on_error(method_name = nil, &block)
      lifecycle_manager.on_error(method_name, &block)
    end

    def self.async(asynchronous = true)
      self.asynchronous = asynchronous
    end

    def self.call_stage_procs(event, job, *args)
      lifecycle_manager.call_callbacks(event, { stage: job.current_stage, job: job }, *args)
    end

    def perform(*args, stage: nil, _output: nil,  **kwargs)
      if self.class.stages.empty?
        raise StagedJob::NoStagesError, "No stages defined for #{self.class.name}"
      end

      validate_params!(kwargs)

      stage ||= stages.first

      if _output != nil
        self.output = _output
      end

      # Capture the params to pass along to the stages
      self.params = kwargs
      self.current_stage = stage

      if pending?
        self.class.call_stage_procs(:before_start, self)
      end

      self.status = Status::RUNNING

      self.class.call_stage_procs(:before_stage, self, self.current_stage)

      begin
        perform_stage(stage, **kwargs)
      rescue => error
        # TODO: Call the NEW lifecycle stuff
        self.status = Status::FAILED
        self.class.call_stage_procs(:on_error, self, error)

        # If there's no on_error catcher, re-raise the exception
        raise error if self.class.lifecycle_manager.callbacks[:on_error].empty?
      end

      # If hte job has failed, let's just exit early
      #
      # TODO: Determine what DelayedJob, et. al do with this
      # failed job. Do they requeue it themselves?  That's
      # probably okay, so long as we can re-adjust our status.
      if failed?
        return
      end

      self.class.call_stage_procs(:after_stage, self)

      unless last_stage?
        transition_to(next_stage)
      else
        self.status = Status::FINISHED
        self.class.call_stage_procs(:after_finish, self)
      end
    end

    def perform_stage(stage, **args)
      send("perform_stage_#{stage}", **args)
    end

    def transition_to(stage)
      requeue_or_run(stage)
    end

    def requeue_or_run(stage)
      if self.class.asynchronous
        self.class.set(wait: 1.seconds).perform_later(stage: stage, _output: self.output, **params)
      else
        perform(stage: stage, **params)
      end
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

    def last_stage?
      stages.last == current_stage
    end

    def next_stage
      stages[stages.index(current_stage) + 1]
    end

  private

    def validate_params!(args)
      missing_args = parameters - args.keys

      if missing_args.any?
        raise ArgumentError, "Missing arguments: #{missing_args.join(', ')}"
      end
    end

    def self.build_stage_method(method_name, &block)
      define_method(method_name) do |**args|
        result = instance_exec(**args, &block)

        self.output[current_stage] = result
      end
    end # build_stage_method

  end
end