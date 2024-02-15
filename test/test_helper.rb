$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "staged_job"

require "minitest/autorun"

ActiveJob::Base.queue_adapter = :test

class ActiveSupport::TestCase
end