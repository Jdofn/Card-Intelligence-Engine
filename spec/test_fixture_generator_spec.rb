# frozen_string_literal: true

require_relative "../lib/card_intelligence_engine/test_fixture_generator"

RSpec.describe CardIntelligenceEngine::TestFixtureGenerator do
  it "returns clearly non-payment placeholders for each simulated outcome" do
    fixtures = described_class.all

    expect(fixtures.map { |item| item[:id] }).to include("fixture-success", "fixture-declined", "fixture-pending")
    expect(fixtures).to all(include(
      payment_data_placeholder: "NOT_A_REAL_CARD",
      security_code_placeholder: "NOT_A_CVV",
      expiry_placeholder: "NOT_A_REAL_EXPIRY",
      usable_for_payment: false
    ))
  end

  it "returns an isolated copy for a known fixture" do
    fixture = described_class.find("fixture-success")
    fixture[:scenario] = "changed"

    expect(described_class.find("fixture-success")[:scenario]).to eq("simulated_success")
  end

  it "returns nil for an unknown fixture" do
    expect(described_class.find("missing")).to be_nil
  end
end
