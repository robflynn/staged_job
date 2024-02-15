module StagedJob
  class Job < ActiveJob::Base
    include StagedJob::Concerns::StageManagement
  end
end