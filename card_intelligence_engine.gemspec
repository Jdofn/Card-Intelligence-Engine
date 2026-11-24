# frozen_string_literal: true

require_relative "lib/card_intelligence_engine/version"

Gem::Specification.new do |spec|
  spec.name = "card_intelligence_engine"
  spec.version = CardIntelligenceEngine::VERSION
  spec.summary = "Privacy-conscious BIN/IIN metadata lookup"
  spec.description = "Local-first BIN/IIN metadata lookup with an optional Bincodes API fallback and Paymob Sandbox hosted checkout API."
  spec.authors = ["Card Intelligence Engine contributors"]
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"
  spec.files = Dir["lib/**/*.rb", "app.rb", "config.ru", "Procfile", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md"]
  spec.require_paths = ["lib"]

  # Runtime dependencies used by the optional HTTP payment API.
  spec.add_dependency "credit_card_bins", ">= 0.0.1"
  spec.add_dependency "sinatra", "~> 4.1"
  spec.add_dependency "puma", "~> 6.6"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rack-test", "~> 2.2"
end
