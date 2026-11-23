# frozen_string_literal: true

module CardIntelligenceEngine
  class Error < StandardError; end
  class InvalidBIN < Error; end
  class NotFound < Error; end
  class ProviderError < Error; end
end
