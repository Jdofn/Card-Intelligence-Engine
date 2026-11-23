# Card Intelligence Engine

A Ruby BIN/IIN metadata lookup engine using a **local-first, remote-fallback** strategy, with an optional Paymob Sandbox hosted-checkout adapter.

> Scope: BIN/IIN metadata lookup and authorized merchant payment integration. This project does not test cards, validate whether arbitrary cards are live, retrieve CVVs, or perform unauthorized transactions.

## Features

- Local lookup through the `credit_card_bins` dataset.
- Optional Bincodes API fallback when local metadata is unavailable.
- Strict BIN/IIN input validation: accepts only 6–8 numeric digits; full PAN/card numbers are rejected.
- Optional Paymob Sandbox Payment Intention client.
- Hosted Unified Checkout: customers enter payment data on Paymob, not on this application.
- Transaction callback HMAC verifier and a sanitized transaction summary.
- No CVV or full PAN storage or logging.

## Requirements

- Ruby 3.0+
- Bundler

## Setup

```bash
bundle install
```

## BIN/IIN lookup

```ruby
require "card_intelligence_engine"

metadata = CardIntelligenceEngine.lookup("411111")
puts metadata
```

## Paymob Sandbox

Configure these values as environment variables or deployment secrets. Never commit real credentials:

- `PAYMOB_SECRET_KEY` — test secret key (must start with `sk_test_`).
- `PAYMOB_PUBLIC_KEY` — test public key.
- `PAYMOB_INTEGRATION_ID` — test card integration ID.
- `PAYMOB_HMAC_SECRET` — test HMAC secret.
- `PAYMOB_NOTIFICATION_URL` — public HTTPS webhook endpoint.
- `PAYMOB_REDIRECTION_URL` — HTTPS return URL.

Example:

```ruby
require "card_intelligence_engine/paymob"

client = CardIntelligenceEngine::Paymob::Client.new
checkout = client.create_checkout(
  amount_cents: 1250, # EGP 12.50
  item_name: "Example order",
  billing_data: {
    "first_name" => "Test",
    "last_name" => "Customer",
    "email" => "test@example.com",
    "phone_number" => "+201000000000",
    "country" => "EG",
    "city" => "Cairo"
  },
  notification_url: ENV.fetch("PAYMOB_NOTIFICATION_URL"),
  redirection_url: ENV.fetch("PAYMOB_REDIRECTION_URL")
)

# Return checkout[:checkout_url] to the customer's browser/app.
# Never expose PAYMOB_SECRET_KEY to the client.
```

The adapter is deliberately Sandbox-only. It requires HTTPS callback URLs and returns the hosted checkout URL. The customer enters their card details directly in Paymob Unified Checkout.

### Webhook handling

Use `CardIntelligenceEngine::Paymob::Webhook` to verify the transaction callback HMAC before trusting payment status. The HTTP route/controller must extract the callback HMAC according to the current Paymob callback contract, call `verify_transaction!`, and only then use `safe_transaction_summary`. Do not persist the raw callback: Paymob callback payloads can contain payment and card-related fields.

Do not mark an order paid based on the browser redirect. The verified server-to-server callback is the source of truth. Make callback processing idempotent using the transaction/order ID.

## Security boundaries

- Never collect or store CVV, PIN, full PAN, or raw payment credentials.
- Do not create a card checker, brute-force card data, or probe payment authorization.
- Use only test credentials during development.
- Keep all Paymob keys in Railway/GitHub deployment secrets or another secret manager.
- Do not log request/response bodies from payment endpoints.
- Use a unique internal order reference and verify amount, currency, order ID, and success state before fulfillment.

## Tests

```bash
bundle exec rspec
```

## Upstream projects

- [hugolantaume/credit_card_bins](https://github.com/hugolantaume/credit_card_bins) — local BIN dataset, MIT.
- [serverscom/credit-card-finder](https://github.com/serverscom/credit-card-finder) — reference for the local-first / API-fallback strategy, MIT.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
