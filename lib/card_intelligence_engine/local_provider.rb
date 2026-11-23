# frozen_string_literal: true

require "credit_card_bins"

module CardIntelligenceEngine
  class LocalProvider
    def lookup(bin)
      record = CreditCardBin.new(bin).data
      return nil unless record

      country = record["country"] || {}
      {
        "bin" => bin,
        "brand" => record["brand"],
        "issuer" => record["issuer"],
        "type" => record["type"],
        "category" => record["category"],
        "country" => country["name"],
        "country_code" => country["alpha_2"],
        "source" => "local"
      }.compact
    rescue StandardError => e
      # The upstream gem raises NotFound for absent BIN records; avoid leaking input.
      return nil if e.class.name.split("::").last == "NotFound"

      raise
    end
  end
end
