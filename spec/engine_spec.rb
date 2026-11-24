# frozen_string_literal: true

require_relative "../lib/card_intelligence_engine"

RSpec.describe CardIntelligenceEngine::Engine do
  let(:local) { instance_double(CardIntelligenceEngine::LocalProvider) }
  let(:legacy) { instance_double(CardIntelligenceEngine::LegacyGistProvider) }
  let(:remote) { instance_double(CardIntelligenceEngine::BincodesProvider) }
  subject(:engine) do
    described_class.new(local_provider: local, legacy_provider: legacy, remote_provider: remote)
  end

  it "rejects full card numbers and non-numeric input before provider calls" do
    expect { engine.lookup("4111111111111111") }.to raise_error(CardIntelligenceEngine::InvalidBIN)
    expect { engine.lookup("12AB56") }.to raise_error(CardIntelligenceEngine::InvalidBIN)
  end

  it "returns local metadata without calling fallback providers" do
    result = { "bin" => "411111", "brand" => "VISA", "source" => "local" }
    expect(local).to receive(:lookup).with("411111").and_return(result)
    expect(legacy).not_to receive(:lookup)
    expect(remote).not_to receive(:lookup)
    expect(engine.lookup("411111")).to eq(result)
  end

  it "uses the historical Gist source before the remote provider" do
    result = { "bin" => "654321", "brand" => "MASTERCARD", "source" => "legacy_gist_2020" }
    expect(local).to receive(:lookup).with("654321").and_return(nil)
    expect(legacy).to receive(:lookup).with("654321").and_return(result)
    expect(remote).not_to receive(:lookup)
    expect(engine.lookup("654321")).to eq(result)
  end

  it "uses the remote provider only when local and historical metadata are absent" do
    result = { "bin" => "654321", "brand" => "MASTERCARD", "source" => "bincodes" }
    expect(local).to receive(:lookup).with("654321").and_return(nil)
    expect(legacy).to receive(:lookup).with("654321").and_return(nil)
    expect(remote).to receive(:lookup).with("654321").and_return(result)
    expect(engine.lookup("654321")).to eq(result)
  end

  it "raises NotFound when no provider has metadata" do
    allow(local).to receive(:lookup).and_return(nil)
    allow(legacy).to receive(:lookup).and_return(nil)
    allow(remote).to receive(:lookup).and_return(nil)
    expect { engine.lookup("654321") }.to raise_error(CardIntelligenceEngine::NotFound)
  end
end
