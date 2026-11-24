# frozen_string_literal: true

require "sinatra/base"
require "json"
require "securerandom"
require "card_intelligence_engine"
require_relative "lib/card_intelligence_engine/paymob"

class PaymentAPI < Sinatra::Base
  set :show_exceptions, false
  set :raise_errors, false
  set :logging, false

  before { content_type :json }

  get "/" do
    {
      service: "Card Intelligence Engine",
      status: "online",
      scope: ["BIN/IIN metadata lookup", "Paymob hosted checkout (Sandbox only)"],
      endpoints: {
        health: "GET /health",
        bin_lookup: "GET /api/bin/:bin",
        checkout: "POST /api/checkout",
        paymob_webhook: "POST /payments/paymob/webhook"
      },
      security: "Never submit full card numbers, CVV, PIN, or payment credentials."
    }.to_json
  end

  get "/health" do
    { status: "ok", service: "card-intelligence-engine", payment_mode: "sandbox_only" }.to_json
  end

  get "/api/bin/:bin" do
    result = CardIntelligenceEngine.lookup(params[:bin])
    status 200
    { data: result }.to_json
  rescue CardIntelligenceEngine::InvalidBIN
    status 422
    { error: "invalid_bin_iin", message: "Supply only a 6–8 digit BIN/IIN prefix; full card numbers are not accepted." }.to_json
  rescue CardIntelligenceEngine::NotFound
    status 404
    { error: "bin_metadata_not_found" }.to_json
  rescue CardIntelligenceEngine::ProviderError
    status 502
    { error: "metadata_provider_unavailable" }.to_json
  end

  post "/api/checkout" do
    halt 400, { error: "invalid_json" }.to_json unless request.media_type == "application/json"
    body = JSON.parse(request.body.read)
    amount = Integer(body.fetch("amount_cents"))
    halt 422, { error: "amount_must_be_positive" }.to_json unless amount.positive?

    required_urls = %w[PAYMOB_NOTIFICATION_URL PAYMOB_REDIRECTION_URL]
    missing_urls = required_urls.select { |key| ENV[key].to_s.empty? }
    unless missing_urls.empty?
      status 503
      halt({ error: "sandbox_callback_urls_not_configured" }.to_json)
    end

    client = CardIntelligenceEngine::Paymob::Client.new
    result = client.create_checkout(
      amount_cents: amount,
      item_name: body.fetch("item_name"),
      billing_data: body.fetch("billing_data"),
      notification_url: ENV.fetch("PAYMOB_NOTIFICATION_URL"),
      redirection_url: ENV.fetch("PAYMOB_REDIRECTION_URL"),
      reference: SecureRandom.uuid
    )
    status 201
    { checkout_url: result.fetch(:checkout_url), reference: result.fetch(:reference), mode: "sandbox" }.to_json
  rescue KeyError, ArgumentError
    status 422
    { error: "invalid_checkout_request" }.to_json
  rescue CardIntelligenceEngine::Paymob::ConfigurationError
    status 503
    { error: "sandbox_credentials_not_configured" }.to_json
  rescue CardIntelligenceEngine::Paymob::RequestError
    status 502
    { error: "payment_provider_unavailable" }.to_json
  end

  post "/payments/paymob/webhook" do
    payload = JSON.parse(request.body.read)
    supplied_hmac = params["hmac"] || request.env["HTTP_X_PAYMOB_HMAC"]
    verifier = CardIntelligenceEngine::Paymob::Webhook.new
    verifier.verify_transaction!(payload, supplied_hmac: supplied_hmac)
    summary = verifier.safe_transaction_summary(payload)
    logger.info("Verified Paymob callback: #{summary.to_json}")
    status 200
    { received: true, verified: true }.to_json
  rescue JSON::ParserError
    status 400
    { error: "invalid_json" }.to_json
  rescue CardIntelligenceEngine::Paymob::ConfigurationError
    status 503
    { error: "webhook_secret_not_configured" }.to_json
  rescue CardIntelligenceEngine::Paymob::RequestError, ArgumentError
    status 401
    { error: "invalid_webhook_signature_or_payload" }.to_json
  end

  error do
    status 500
    { error: "internal_server_error" }.to_json
  end
end
