# frozen_string_literal: true

require_relative "../lib/card_intelligence_engine/legacy_gist_provider"

RSpec.describe CardIntelligenceEngine::LegacyGistProvider do
  subject(:provider) { described_class.new }

  it "matches exact prefixes, wildcard prefixes, and abbreviated ranges" do
    expect(provider.send(:matches?, "411111", "411111")).to be(true)
    expect(provider.send(:matches?, "41****", "411111")).to be(true)
    expect(provider.send(:matches?, "400837-39", "400839")).to be(true)
    expect(provider.send(:matches?, "431301 to 05", "431305")).to be(true)
  end

  it "does not match unrelated or malformed patterns" do
    expect(provider.send(:matches?, "411111", "511111")).to be(false)
    expect(provider.send(:matches?, "not-a-bin", "411111")).to be(false)
  end

  it "accepts only a six-digit BIN prefix" do
    expect(provider.lookup("4111111111111111")).to be_nil
    expect(provider.lookup("12AB56")).to be_nil
  end
end
