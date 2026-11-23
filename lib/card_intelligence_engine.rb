# frozen_string_literal: true

require_relative "card_intelligence_engine/version"
require_relative "card_intelligence_engine/errors"
require_relative "card_intelligence_engine/engine"

module CardIntelligenceEngine
  def self.lookup(bin, **options)
    Engine.new(**options).lookup(bin)
  end
end
