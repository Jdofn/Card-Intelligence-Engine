# frozen_string_literal: true

module CardIntelligenceEngine
  # Deliberately non-routable fixture labels for UI and application-state tests.
  # These are not PANs, CVVs, or payment-gateway test credentials.
  module TestFixtureGenerator
    FIXTURES = [
      { id: "fixture-success", brand: "VISA (label only)", scenario: "simulated_success", expected_status: "succeeded" },
      { id: "fixture-declined", brand: "MASTERCARD (label only)", scenario: "simulated_decline", expected_status: "declined" },
      { id: "fixture-pending", brand: "GENERIC (label only)", scenario: "simulated_pending", expected_status: "pending" },
      { id: "fixture-error", brand: "GENERIC (label only)", scenario: "simulated_provider_error", expected_status: "error" },
      { id: "fixture-expired", brand: "GENERIC (label only)", scenario: "simulated_expiry", expected_status: "expired" }
    ].map do |fixture|
      fixture.merge(
        payment_data_placeholder: "NOT_A_REAL_CARD",
        security_code_placeholder: "NOT_A_CVV",
        expiry_placeholder: "NOT_A_REAL_EXPIRY",
        usable_for_payment: false
      ).freeze
    end.freeze

    def self.all
      FIXTURES.map(&:dup)
    end

    def self.find(id)
      fixture = FIXTURES.find { |item| item[:id] == id.to_s }
      fixture&.dup
    end
  end
end
