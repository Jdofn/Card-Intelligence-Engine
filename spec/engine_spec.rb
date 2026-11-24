# frozen_string_literal: true

require_relative "../lib/card_intelligence_engine"

RSpec.describe CardIntelligenceEngine::Engine do
  let(:local) { instance_double(CardIntelligenceEngine::LocalProvider) }
  let(:remote) { instance_double(CardIntelligenceEngine::BincodesProvider) }
  subject(:engine) { described_class.new(local_provider: local, remote_provider: remote) }

  it "rejects full card numbers and non-numeric input before provider calls" do
    expect { engine.lookup("4111111111111111") }.to raise_error(CardIntelligenceEngine::InvalidBIN)
    expect { engine.lookup("12AB56") }.to raise_error(CardIntelligenceEngine::InvalidBIN)
  end

  it "returns local metadata without calling the remote provider" do
    result = { "bin" => "411111", "brand" => "VISA", "source" => "local" }
    expect(local).to receive(:lookup).with("411111").and_return(result)
    expect(remote).not_to receive(:lookup)
    expect(engine.lookup("411111")).to eq(result)
  end

  it "uses the remote provider only when local metadata is absent" do
    result = { "bin" => "654321", "brand" => "MASTERCARD", "source" => "bincodes" }
    expect(local).to receive(:lookup).with("654321").and_return(nil)
    expect(remote).to receive(:lookup).with("654321").and_return(result)
    expect(engine.lookup("654321")).to eq(result)
  end

  it "raises NotFound when neither provider has metadata" do
    allow(local).to receive(:lookup).and_return(nil)
    allow(remote).to receive(:lookup).and_return(nil)
    expect { engine.lookup("654321") }.to raise_error(CardIntelligenceEngine::NotFound)
  end
end
