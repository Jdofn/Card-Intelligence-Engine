# frozen_string_literal: true

require "json"
require "rspec"
require_relative "../lib/card_intelligence_engine/paymob"

RSpec.describe CardIntelligenceEngine::Paymob::Client do
  let(:client) do
    described_class.new(
      secret_key: "sk_test_example",
      public_key: "pk_test_example",
      integration_id: "123",
      api_base: "https://accept.paymob.com",
      http: Class.new do
        def self.start(*, **)
          yield self
        end

        def self.request(request)
          Struct.new(:code, :body).new("201", JSON.generate(
            "id" => "pi_test_123",
            "intention_order_id" => 456,
            "client_secret" => "egy_csk_test_example"
          ))
        end
      end
    )
  end

  it "creates a hosted checkout intention and returns a Paymob checkout URL" do
    result = client.create_checkout(
      amount_cents: 1250,
      item_name: "Test order",
      billing_data: { "phone_number" => "+201000000000" },
      notification_url: "https://merchant.example/webhook",
      redirection_url: "https://merchant.example/complete"
    )

    expect(result[:order_id]).to eq(456)
    expect(result[:checkout_url]).to include("publicKey=pk_test_example")
    expect(result[:checkout_url]).to include("clientSecret=egy_csk_test_example")
  end

  it "rejects non-HTTPS callback URLs" do
    expect do
      client.create_checkout(
        amount_cents: 100,
        item_name: "Test",
        billing_data: { "phone_number" => "+201000000000" },
        notification_url: "http://insecure.example/webhook",
        redirection_url: "https://merchant.example/complete"
      )
    end.to raise_error(ArgumentError, /notification_url must be HTTPS/)
  end

  it "rejects live credentials in this sandbox-only client" do
    live = described_class.new(
      secret_key: "sk_live_example",
      public_key: "pk_live_example",
      integration_id: "123"
    )
    expect do
      live.create_checkout(
        amount_cents: 100,
        item_name: "Test",
        billing_data: { "phone_number" => "+201000000000" },
        notification_url: "https://merchant.example/webhook",
        redirection_url: "https://merchant.example/complete"
      )
    end.to raise_error(CardIntelligenceEngine::Paymob::ConfigurationError, /Sandbox mode/)
  end
end

RSpec.describe CardIntelligenceEngine::Paymob::Webhook do
  it "rejects callbacks when the HMAC secret is not configured" do
    verifier = described_class.new(hmac_secret: nil)
    expect do
      verifier.verify_transaction!({ "obj" => {} }, supplied_hmac: "bad")
    end.to raise_error(CardIntelligenceEngine::Paymob::ConfigurationError)
  end

  it "does not include card data in the safe transaction summary" do
    verifier = described_class.new(hmac_secret: "test-secret")
    payload = {
      "type" => "TRANSACTION",
      "obj" => {
        "id" => 1, "order" => { "id" => 2 }, "amount_cents" => 100,
        "currency" => "EGP", "success" => true, "pending" => false,
        "error_occured" => false, "source_data" => { "pan" => "411111******1111" }
      }
    }
    summary = verifier.safe_transaction_summary(payload)
    expect(summary).not_to have_key(:card_number)
    expect(summary).not_to have_key(:cvv)
    expect(summary[:success]).to be(true)
  end
end
