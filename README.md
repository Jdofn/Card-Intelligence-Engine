# Card Intelligence Engine

A Ruby BIN/IIN metadata lookup engine with a browser UI, local-first metadata lookup, optional historical Gist fallback, optional Bincodes fallback, a privacy-preserving local card-format check, and a Paymob Sandbox hosted-checkout adapter.

**Scope:** issuer/card-product metadata and local format checks only. The local card-format page runs the Luhn checksum entirely in the browser and never sends or stores the entered number. It cannot establish whether a card is active, funded, unexpired, or authorized. This service does not retrieve or validate CVVs. Its synthetic fixture endpoint returns scenario labels and non-numeric placeholders only; these are not payment credentials and cannot be used for transactions.

## Live service

- Browser BIN/IIN lookup: `/`
- Local card format + Luhn check: `/card-format-check.html` (browser-only; no network submission)
- Health: `/health`
- BIN/IIN metadata: `GET /api/bin/:bin` (6–8 numeric digits only)
- Synthetic test fixtures: `GET /api/test-fixtures` and `GET /api/test-fixtures/:id` (non-payment placeholders only; no PAN/CVV values).
- Paymob hosted checkout: `POST /api/checkout` (Sandbox only; returns HTTP 503 until test credentials are configured)
- Paymob webhook: `POST /payments/paymob/webhook`
- Payment return: `GET /payments/complete` (pending until the verified server callback arrives)

## BIN/IIN lookup order

1. Bundled `credit_card_bins` dataset (primary; no external request).
2. Historical 2020 Gist reference (only when the primary dataset has no match; fetched on demand and cached in memory for 24 hours).
3. Optional Bincodes API fallback via `BINCODES_API_KEY`.

The historical source is [mahmoudimus/bin_db.sql](https://gist.github.com/mahmoudimus/4bdf559c943d4c69640a748e1b94aa3d), created on 2020-06-30. Results from it are explicitly tagged `source=legacy_gist_2020`, include the dataset date and source URL, and expose the historical description rather than presenting it as verified current issuer data. This old list can contain obsolete or inaccurate entries; use it as a last-resort reference only. The Gist does not declare an explicit reuse license, so the application fetches it at runtime rather than vendoring or redistributing its SQL contents. If the source becomes unavailable, lookup continues to the Bincodes fallback.

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

The customer enters card details directly on Paymob Hosted Checkout. This application never collects or stores PAN, CVV, or PIN. Use Paymob's official Sandbox test-card data for payment success/failure scenarios. The `/api/test-fixtures` endpoint is only for exercising application UI/state handling and is not a substitute for gateway Sandbox credentials. The browser redirect is not treated as proof of payment; only a verified server-to-server webhook can confirm it.

## Production limitation

This deployment is suitable for BIN/IIN metadata lookup, local format checks, and Sandbox integration testing once credentials are configured. It is **not ready for live payments or order fulfillment**: it does not yet persist orders, enforce durable webhook idempotency, reconcile amount/currency/reference against a stored order, or provide replay protection. Do not enable live payment credentials until those controls and monitoring are implemented and reviewed.

## Upstream projects

- [hugolantaume/credit_card_bins](https://github.com/hugolantaume/credit_card_bins) — local BIN dataset, MIT.
- [serverscom/credit-card-finder](https://github.com/serverscom/credit-card-finder) — reference for local-first / API-fallback lookup, MIT.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
