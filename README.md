# Crypto Price API

Small Rails API that fetches crypto prices from CoinGecko, caches them, and
keeps serving the last known price if CoinGecko is unreachable.

## Setup

```bash
bundle install
bin/rails db:create db:migrate
cp .env.example .env   # then fill in COINGECKO_API_KEY
```

**Do not hardcode the API key in source.** Set it as an environment
variable (`COINGECKO_API_KEY`) or via `bin/rails credentials:edit` in a
real deployment. If a key was ever pasted into a chat, ticket, or commit,
treat it as compromised and rotate it on CoinGecko's dashboard.

## Running

```bash
bin/rails server
```

Fetch prices once immediately (useful for local testing, no cron needed):

```bash
bin/rails crypto:fetch_prices
```

Then:

```bash
curl http://localhost:3000/prices/btc
# => {"symbol":"btc","price":65000.5,"vs_currency":"usd","fetched_at":"...","stale":false}
```

## Running it every minute

`config/schedule.rb` (via the `whenever` gem) is set up to enqueue
`FetchCryptoPriceJob` every minute:

```bash
bundle exec whenever --update-crontab
```

In containerized/production setups, swap this for your platform's
scheduler (Heroku Scheduler, a Kubernetes CronJob, `sidekiq-cron`, etc.)
calling the same job.

## How it works

- **`CoingeckoClient`** (`app/services`) — talks to CoinGecko's
  `simple/price` endpoint. Any failure (bad status, timeout, connection
  error, missing data) is normalized into `CoingeckoClient::Error`.
- **`FetchCryptoPriceJob`** (`app/jobs`) — runs on a schedule, fetches
  every configured symbol independently. On success it upserts the price.
  On failure for a given symbol, it **rescues the error, logs a warning,
  and leaves that symbol's stored price untouched** — this is the
  fallback behavior. One symbol failing doesn't affect the others.
- **`CryptoPrice`** (`app/models`) — the source of truth (DB row per
  symbol) plus a `Rails.cache` read-through layer (`cached_for`) so
  `GET /prices/:symbol` never has to hit the DB or CoinGecko directly.
  Cache entries expire after `price_cache_ttl` (default 90s) and are
  transparently repopulated from the DB on the next read.
- **`PricesController`** — only ever reads via `CryptoPrice.cached_for`.
  It flags a response as `stale: true` if the underlying price is older
  than `price_stale_ttl` (default 1 day) — still served, just labeled,
  so API consumers know CoinGecko may have been down for a while.
- Symbols are mapped to CoinGecko coin ids in
  `config/application.rb` (`config.x.coingecko_symbol_map`) — add more
  there as needed.

## Tests

```bash
bundle exec rspec
```

- `spec/services/coingecko_client_spec.rb` — HTTP client success/error
  handling (bad status, timeout, connection failure, malformed body).
- `spec/jobs/fetch_crypto_price_job_spec.rb` — job logic (fetches every
  configured symbol, isolates per-symbol failures) and fallback logic
  (a failed fetch never overwrites the last known price, in DB or cache).
- `spec/models/crypto_price_spec.rb` — caching behavior (cache
  hit/miss/write-through, `skip_nil` behavior, upsert on repeated writes).
- `spec/requests/prices_spec.rb` — end-to-end controller behavior,
  including the `stale` flag and unknown/unrecorded symbol handling.
