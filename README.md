# Cartwell — E-Commerce Order Platform

A complete demo storefront with a Rails 7.2 API, React/Vite client, PostgreSQL inventory, Redis versioned catalog caching, Sidekiq outbox workers, and Docker Compose. This is a **demo order workflow, not a payment processor**; no credit card collection or actual emails are sent.

## Quick start

Prerequisites: Docker Engine + Docker Compose plugin.

```bash
docker compose up --build -d
docker compose exec api bundle exec rails db:seed
```

Open **http://localhost:5173**. API health: **http://localhost:3000/api/health**. To populate the full catalog:

```bash
docker compose exec -e PRODUCT_COUNT=100000 api bundle exec rails db:seed
```

Seed is repeatable and upserts SKUs. Initial seed is 100 products. Product photos are illustrative remote Picsum images and need internet access. A product still works if the image fails to load.

## Features and architecture

- **Storefront:** searchable, paginated products; cart quantity controls; checkout; order confirmation; order lookup; cancellation API.
- **Concurrency-safe checkout:** transaction, advisory lock on idempotency key, deterministic PostgreSQL `SELECT ... FOR UPDATE` product row locks, server-calculated totals, nonnegative stock constraint, unique order key, and request-digest conflict check.
- **Outbox + Sidekiq:** durable outbox rows created atomically with orders; retries and deduplicated database-backed local delivery receipts. `DispatchOutboxJob` enqueues pending events, `ProcessOutboxEventJob` processes each exactly once in the database. Run `rake outbox:dispatch` periodically for recovery if enqueue fails. Real external emails/webhooks require a provider with an idempotency key and a transactional delivery strategy; the local receipt is deliberately not represented as a real email.
- **Catalog:** pagination with `limit <= 100`, ILIKE search, indexes on SKU and active/id, no N+1 order serialization via `includes`, Redis pooled connections, metadata version invalidation, and short-lived inventory snapshots (5-second TTL). Cache unavailable → DB fallback.
- **100K products:** set `PRODUCT_COUNT=100000` during seed. Catalog search is intentionally basic ILIKE and would benefit from `pg_trgm` GIN indexes at larger scale.

## API

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Database health |
| GET | `/api/products?page=1&limit=20&q=chair` | Catalog |
| GET | `/api/products/:id` | Product details |
| POST | `/api/orders` | Checkout; requires `Idempotency-Key` header |
| GET | `/api/orders/:id` | Order details |
| POST | `/api/orders/:id/cancel` | Restore inventory once |

Example checkout:

```bash
curl -X POST http://localhost:3000/api/orders \
  -H 'Content-Type: application/json' -H 'Idempotency-Key: my-checkout-001' \
  -d '{"email":"buyer@example.com","items":[{"product_id":1,"quantity":2}]}'
```

## Tests

```bash
docker compose exec api bundle exec rails db:test:prepare
docker compose exec api bundle exec rspec
docker compose exec frontend npm test -- --run
docker compose exec frontend npm run build
```

Concurrency stress and performance measurement:

```bash
docker compose exec -e RAILS_MAX_THREADS=30 -e THREADS=20 -e ATTEMPTS=5000 api bundle exec rails runner scripts/concurrency_test.rb
docker compose exec api bundle exec rails runner scripts/benchmark_checkout.rb
docker compose exec api bundle exec rails runner scripts/benchmark_catalog.rb
```

`RAILS_MAX_THREADS` must exceed `THREADS` to avoid pool starvation. The concurrency test mixes repeated idempotency keys and independent competing purchases, checking that unique orders plus remaining stock equals initial stock. Checkout and catalog benchmark scripts print measurements from the local environment.

## Important production limitations

This is a working demo architecture, **not production-ready commerce**. It has no authentication/authorization (order IDs can be queried or cancelled by anyone), real payment capture, tax/shipping calculation, email provider, rate limiting, CSRF mitigation for cookie sessions, observability stack, distributed tracing, or inventory reservation expiry. Do not expose it to the public internet or process real orders. The event delivery adapter is a local durable receipt, not external delivery. Production deployments should use authenticated identities, a payment gateway with webhook reconciliation, real fulfillment integrations, and an outbox poller/scheduler. Concurrent cancellation and checkout follow consistent product locking only for checkout; use careful lock ordering for complex fulfillment workflows.

## CI and repeatable catalog load test

GitHub Actions is configured to run Rails RSpec with PostgreSQL/Redis and frontend Vitest/build on every push and pull request. The workflows must pass on GitHub before treating them as verified. Generate and commit `Gemfile.lock` and `frontend/package-lock.json` with package-registry access before enabling reproducible CI installs.

## Catalog performance comparison

For an apples-to-apples **hot catalog page** comparison, seed the same database with 100,000 products and run the API in two separate configurations, with Redis running in both:

- Cached: `CATALOG_CACHE=on` (default); run `LABEL=cached bash scripts/load_catalog.sh`.
- Uncached: restart the API with `CATALOG_CACHE=off`; run `LABEL=uncached bash scripts/load_catalog.sh`.

Keep request count, concurrency, dataset, and hardware identical. The script saves `hey` throughput and latency reports in `catalog-results/`. These are measurements to collect, not predetermined results.
