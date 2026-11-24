# frozen_string_literal: true

require "rack/test"
require_relative "../app"

RSpec.describe PaymentAPI do
  include Rack::Test::Methods

  def app
    PaymentAPI
  end

  it "exposes a health endpoint without payment credentials" do
    get "/health"
    expect(last_response).to be_ok
    expect(JSON.parse(last_response.body)).to include(
      "status" => "ok",
      "payment_mode" => "sandbox_only"
    )
  end

  it "keeps checkout disabled until sandbox credentials are configured" do
    %w[PAYMOB_SECRET_KEY PAYMOB_PUBLIC_KEY PAYMOB_INTEGRATION_ID].each { |key| ENV.delete(key) }
    post "/api/checkout",
         { amount_cents: 100, item_name: "Test", billing_data: { phone_number: "+201000000000" } }.to_json,
         "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(503)
    expect(JSON.parse(last_response.body)).to include("error" => "sandbox_credentials_not_configured")
  end

  it "rejects malformed webhook JSON" do
    post "/payments/paymob/webhook", "{", "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(400)
  end
end
