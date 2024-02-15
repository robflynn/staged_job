# frozen_string_literal: true

require_relative "lib/staged_job/version"

Gem::Specification.new do |spec|
  spec.name = "staged_job"
  spec.version = StagedJob::VERSION
  spec.authors = ["Rob Flynn"]
  spec.email = ["rob@thingerly.com"]

  spec.summary = "Write a short summary, because RubyGems requires one."
  spec.description = "Write a longer description or delete this line."
  spec.homepage = "https://github.com/robflynn/staged_job"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/robflynn/staged_job"


  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "activerecord", "~> 6.0"
  spec.add_development_dependency "minitest", "~> 5.22"
  spec.add_development_dependency "mocha", "~> 2.1.0"
  spec.add_development_dependency "minitest-stub-const", "~> 0.6"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
