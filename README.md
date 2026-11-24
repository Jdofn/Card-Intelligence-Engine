# Card Intelligence Engine

A Ruby BIN/IIN metadata lookup engine with a small browser UI, local-first metadata lookup, optional Bincodes fallback, and a Paymob Sandbox hosted-checkout adapter.

**Scope:** issuer/card-product metadata only. This service does not check whether cards are live, test payment authorization, retrieve CVVs, or accept full card numbers.

## Live service

- Browser lookup: `/`
- Health: `/health`
- BIN/IIN metadata: `GET /api/bin/:bin` (6–8 numeric digits only)
- Paymob hosted checkout: `POST /api/checkout` (Sandbox only; returns HTTP 503 until test credentials are configured)
- Paymob webhook: `POST /payments/paymob/webhook`
- Payment return: `GET /payments/complete` (pending until the verified server callback arrives)

## Data providers

1. Bundled `credit_card_bins` dataset (works without external credentials).
2. Optional Bincodes API fallback via `BINCODES_API_KEY`.

## Runtime and tests

Ruby 3.4 / Bundler / Puma. Install and test locally:

```bash
bundle install
bundle exec rspec
```

## Paymob Sandbox configuration

Set these only in Railway Variables/Secrets; never commit or paste secret values into chat:

- `PAYMOB_SECRET_KEY` — Sandbox secret key (`sk_test_...`).
- `PAYMOB_PUBLIC_KEY` — Sandbox public key.
- `PAYMOB_INTEGRATION_ID` — Sandbox card integration ID.
- `PAYMOB_HMAC_SECRET` — Sandbox webhook HMAC secret.
- `PAYMOB_NOTIFICATION_URL` — configured to this service's webhook endpoint.
- `PAYMOB_REDIRECTION_URL` — configured to this service's payment-return endpoint.

The customer enters card details directly on Paymob Hosted Checkout. This application never collects or stores PAN, CVV, or PIN. The browser redirect is not treated as proof of payment; only a verified server-to-server webhook can confirm it.

## Production limitation

This deployment is suitable for BIN/IIN metadata lookup and Sandbox integration testing. It is **not ready for live payments or order fulfillment**: it does not yet persist orders, enforce durable webhook idempotency, reconcile amount/currency/reference against a stored order, or provide replay protection. Do not enable live payment credentials until those controls and monitoring are implemented and reviewed.

## Upstream projects

- [hugolantaume/credit_card_bins](https://github.com/hugolantaume/credit_card_bins) — local BIN dataset, MIT.
- [serverscom/credit-card-finder](https://github.com/serverscom/credit-card-finder) — reference for local-first / API-fallback lookup, MIT.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
