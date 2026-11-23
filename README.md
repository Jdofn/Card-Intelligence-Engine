# Card Intelligence Engine

A Ruby BIN/IIN metadata lookup engine using a **local-first, remote-fallback** strategy.

> Scope: metadata about a BIN/IIN prefix only (issuer, brand, card type, category, and country). This project does not validate payment credentials, process transactions, test cards, or retrieve balances, CVVs, expiry dates, or cardholder data.

## Features

- Local lookup through the `credit_card_bins` dataset.
- Optional Bincodes API fallback when local metadata is unavailable.
- Strict input validation: accepts only 6–8 numeric BIN/IIN digits; full PAN/card numbers are rejected.
- API credentials are read from `BINCODES_API_KEY`; no key is committed to source control.
- Typed errors and RSpec coverage for the lookup strategy.
- Upstream license and attribution notes in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Requirements

- Ruby 3.0+
- Bundler

## Setup

```bash
bundle install
```

For local-only use, no API key is required. To enable the optional remote fallback, set your key in the environment:

```bash
export BINCODES_API_KEY="your_api_key"
```

Never paste a real API key into source files or commit it to Git.

## Usage

```ruby
require "card_intelligence_engine"

metadata = CardIntelligenceEngine.lookup("411111")
puts metadata
```

Or inject providers for testing/custom integrations:

```ruby
engine = CardIntelligenceEngine::Engine.new
metadata = engine.lookup("411111")
```

The engine queries the local dataset first. It calls Bincodes only if local metadata is absent and an API key is configured.

## Tests

```bash
bundle exec rspec
```

## Data and privacy

Supply only a BIN/IIN prefix (6–8 digits), not a full payment card number. The engine does not need or accept CVV, expiry date, PIN, or cardholder name. Do not log or store full payment credentials. BIN metadata can be incomplete or outdated and must not be used to make authorization or fraud decisions.

## Upstream projects

- [hugolantaume/credit_card_bins](https://github.com/hugolantaume/credit_card_bins) — local BIN dataset, MIT.
- [serverscom/credit-card-finder](https://github.com/serverscom/credit-card-finder) — reference for the local-first / API-fallback strategy, MIT.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
