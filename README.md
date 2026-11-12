# Mastodon on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/fnCrEa?utm_medium=integration&utm_source=button&utm_campaign=mastodon)

Railway template for [Mastodon](https://github.com/mastodon/mastodon), the decentralised social network server.

## What it deploys

Mastodon **v4.7.5**, the official images pinned by digest:

- `ghcr.io/mastodon/mastodon:v4.7.5@sha256:1cf98fb199f8cc1dcf4bb174095656bd5e19e99f29e935c2a838132083e1f609`
- `ghcr.io/mastodon/mastodon-streaming:v4.7.5@sha256:3859d071e61a0ed2610a00e8048d89310235afb86e6923c0243bb4f9f4a31093`

| Service | Built from | What it does |
|---|---|---|
| `mastodon` | [`web/`](web) | Web app and API (Puma). On every start it runs `rails db:prepare` (schema on the first start, migrations after upgrades). On the first start only it creates the Owner account (`bootstrap.rb`) and closes sign-ups. Public domain, health check `/health` |
| `sidekiq` | [`sidekiq/`](sidekiq) | Background jobs: federation, media processing, e-mail. Waits until the web service has loaded the schema |
| `streaming` | [`streaming/`](streaming) | Real-time API (the official streaming image, unchanged). Public domain, health check `/api/v1/streaming/health` |
| `media` | [`media/`](media) | Read-only server for the private Railway bucket (Railway buckets can't be public). GET and HEAD by file key only, with Range support; no listing, no writes. Mastodon's `S3_ALIAS_HOST` points at it. Public domain, health check `/health` |
| `Postgres` | Railway Postgres 18 (image) | Accounts, posts, federation state |
| `Redis` | Railway Redis 8.2 (image) | Sidekiq queues, caches, streaming |
| `Bucket` | Railway bucket | Uploads and cached remote media |

Each service folder has a `Dockerfile` (`FROM` the pinned official image, plus the small start script it needs) and a `railway.json` (Dockerfile builder, health check, restart on failure). `web/start.sh` and `sidekiq/start.sh` are identical copies; change both together.

`start.sh` sets the fixed Railway settings: media in the bucket without ACLs, `TRUSTED_PROXY_IP` for Railway's proxy (so Mastodon sees real client IPs), `RAILS_SERVE_STATIC_FILES=true`, Puma in single mode with 5 threads, and e-mail dropped instead of retried until `SMTP_SERVER` is set. It also derives a stable Web Push (VAPID) key pair from `SECRET_KEY_BASE` unless `VAPID_PRIVATE_KEY` and `VAPID_PUBLIC_KEY` are set.

## Variables (on the `mastodon` service)

| Variable | Template default | Description |
|---|---|---|
| `ADMIN_EMAIL` | *(you fill it in)* | E-mail of the Owner account. Its domain must have an MX record |
| `ADMIN_USERNAME` | `admin` | Username of the Owner account (`@username@your-domain`) |
| `ADMIN_PASSWORD` | `${{secret(24)}}` | Owner password, set once on the first start |
| `LOCAL_DOMAIN` | `${{RAILWAY_PUBLIC_DOMAIN}}` | The server's domain in every handle. It can't change once the server has federated |
| `SECRET_KEY_BASE`, `ACTIVE_RECORD_ENCRYPTION_*` | `${{secret(…)}}` | Generated keys. Never change them after the first start |
| `SMTP_SERVER`, `SMTP_PORT`, `SMTP_LOGIN`, `SMTP_PASSWORD`, `SMTP_FROM_ADDRESS` | empty | Optional mail server. Without it, e-mails are dropped |

Database, Redis and bucket settings are Railway reference variables (`${{Postgres.DATABASE_URL}}`, `${{Redis.REDIS_URL}}`, `${{Bucket.…}}`). `sidekiq` reads the shared settings from `mastodon` through `${{mastodon.…}}` references.

**Custom domain:** add it to the `mastodon` service and set `LOCAL_DOMAIN` to it *before* the first start. Mastodon can't change its domain later.

## Updates

Projects deployed from the template build from this repo's `main` branch. When a new version is merged to `main`, Railway shows those projects an "update available" notice, and each owner chooses when to apply it. Every version is listed in [CHANGELOG.md](CHANGELOG.md), with breaking changes first. The web service runs database migrations on start, so an upgrade needs no manual step unless the changelog says so.
