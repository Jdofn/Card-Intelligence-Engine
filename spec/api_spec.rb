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

  it "exposes service information at the root endpoint" do
    get "/"
    expect(last_response).to be_ok
    expect(last_response.headers["content-type"]).to include("text/html")
    expect(last_response.body).to include("BIN / IIN Lookup", "/api/bin/")
  end

  it "rejects full card numbers on the BIN endpoint" do
    get "/api/bin/4111111111111111"
    expect(last_response.status).to eq(422)
    expect(JSON.parse(last_response.body)).to include("error" => "invalid_bin_iin")
  end

  it "keeps checkout disabled until sandbox credentials are configured" do
    %w[PAYMOB_SECRET_KEY PAYMOB_PUBLIC_KEY PAYMOB_INTEGRATION_ID].each { |key| ENV.delete(key) }
    ENV["PAYMOB_NOTIFICATION_URL"] = "https://example.com/paymob/webhook"
    ENV["PAYMOB_REDIRECTION_URL"] = "https://example.com/payment/return"
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
