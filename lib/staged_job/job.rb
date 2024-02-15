module StagedJob
  class Job < ActiveJob::Base
    include StagedJob::Concerns::StageManagement

    def perform(*args)
      puts "Runinng the job with args: #{args}"
    end
  end
end