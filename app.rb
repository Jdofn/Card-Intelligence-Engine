# frozen_string_literal: true

require "sinatra/base"
require "json"
require "securerandom"
require_relative "lib/card_intelligence_engine"
require_relative "lib/card_intelligence_engine/paymob"

class PaymentAPI < Sinatra::Base
  set :show_exceptions, false
  set :raise_errors, false
  set :logging, false
  # This API does not construct absolute URLs from the Host header; allow Railway internal health probes.
  set :host_authorization, permitted_hosts: []

  before { content_type :json }

  get "/" do
    content_type :html
    <<~HTML
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="BIN/IIN metadata lookup using public and local reference data.">
        <title>Card Intelligence Engine</title>
        <style>
          :root{color-scheme:dark;font-family:Inter,system-ui,sans-serif;background:#0b1020;color:#e9eefb}
          *{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;padding:24px}
          main{width:min(720px,100%);background:#121a30;border:1px solid #273452;border-radius:22px;padding:clamp(22px,5vw,42px);box-shadow:0 24px 80px #0006}
          .eyebrow{color:#7dd3fc;font-size:12px;font-weight:700;letter-spacing:.16em;text-transform:uppercase}
          h1{font-size:clamp(30px,6vw,46px);line-height:1.05;margin:14px 0}
          p{color:#aebbd5;line-height:1.6}.form{display:flex;gap:10px;margin:26px 0 12px}
          input{min-width:0;flex:1;background:#0b1224;border:1px solid #344566;color:white;border-radius:12px;padding:15px;font:inherit}
          button{border:0;border-radius:12px;background:#38bdf8;color:#082033;font-weight:800;padding:0 20px;cursor:pointer}
          button:disabled{opacity:.55;cursor:wait}.hint{font-size:13px}
          pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#0b1224;border:1px solid #273452;padding:18px;border-radius:12px;min-height:70px;color:#dbeafe}
          footer{border-top:1px solid #273452;margin-top:24px;padding-top:18px;font-size:12px;color:#91a1bf}
          @media(max-width:520px){.form{flex-direction:column}button{padding:14px}}
        </style>
      </head>
      <body>
        <main>
          <div class="eyebrow">Card Intelligence Engine</div>
          <h1>BIN / IIN Lookup</h1>
          <p>Look up issuer and card metadata from the first 6–8 digits only. No payment-card validation or authorization testing is performed.</p>
          <form class="form" id="lookup-form">
            <input id="bin" name="bin" inputmode="numeric" autocomplete="off" minlength="6" maxlength="8" pattern="[0-9]{6,8}" placeholder="Enter 6–8 digit BIN/IIN" required aria-label="BIN or IIN prefix">
            <button id="submit" type="submit">Look up</button>
          </form>
          <p class="hint">Do not enter a full card number, CVV, PIN, or other payment credentials.</p>
          <pre id="result" aria-live="polite">Lookup results will appear here.</pre>
          <footer>Metadata only · Local reference data · Optional Bincodes provider · Paymob checkout remains Sandbox-only</footer>
        </main>
        <script>
          const form=document.getElementById("lookup-form");
          const input=document.getElementById("bin");
          const output=document.getElementById("result");
          const button=document.getElementById("submit");
          form.addEventListener("submit",async(event)=>{
            event.preventDefault();
            const bin=input.value.trim();
            if(!/^[0-9]{6,8}$/.test(bin)){output.textContent="Enter a 6–8 digit BIN/IIN prefix.";return;}
            button.disabled=true;output.textContent="Looking up metadata…";
            try{
              const response=await fetch("/api/bin/"+encodeURIComponent(bin),{headers:{"Accept":"application/json"}});
              const payload=await response.json();
              output.textContent=JSON.stringify(payload,null,2);
            }catch(error){output.textContent="Lookup service is temporarily unavailable.";}
            finally{button.disabled=false;}
          });
        </script>
      </body>
      </html>
    HTML
  end

  get "/health" do
    { status: "ok", service: "card-intelligence-engine", payment_mode: "sandbox_only" }.to_json
  end

  get "/payments/complete" do
    {
      status: "pending_confirmation",
      reference: params["reference"],
      message: "Payment status is confirmed by the verified Paymob server callback, not by this browser redirect."
    }.compact.to_json
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
