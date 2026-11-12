# Changelog

Each entry is one version of this Railway template. Breaking changes are listed first.
Read the entry before you apply an update in Railway.

## 4.7.5-1 (2026-11-12)

- First version: Mastodon v4.7.5.
  - `ghcr.io/mastodon/mastodon:v4.7.5@sha256:1cf98fb199f8cc1dcf4bb174095656bd5e19e99f29e935c2a838132083e1f609`
  - `ghcr.io/mastodon/mastodon-streaming:v4.7.5@sha256:3859d071e61a0ed2610a00e8048d89310235afb86e6923c0243bb4f9f4a31093`
- Services `mastodon` (web), `sidekiq`, `streaming` and `media` build from this repo; Postgres, Redis and a bucket from Railway.
- Creates the Owner account on the first start and keeps sign-ups closed.
