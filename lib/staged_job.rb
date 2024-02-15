# frozen_string_literal: true

require "bundler/setup"
require "active_job"
require "securerandom"

require 'active_support'
require 'active_support/concern'
require 'active_support/core_ext/class/attribute'

require "staged_job/concerns/stage_management"
require "staged_job/job"

require_relative "staged_job/version"

module StagedJob
  class Error < StandardError; end
  # Your code goes here...
end
