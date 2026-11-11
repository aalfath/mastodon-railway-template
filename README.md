# Mastodon on Railway: start scripts

Readable source of the start scripts used by the Mastodon Railway template
(official `ghcr.io/mastodon/mastodon` and `ghcr.io/mastodon/mastodon-streaming` v4.7.5 images, pinned by digest).

Railway templates can't build from this repo, so the template inlines these files in each service's start command as a
base64 `tar.gz` blob:

```sh
/bin/sh -c 'mkdir -p /tmp/railway && echo <blob> | base64 -d | tar xz -C /tmp/railway && exec sh /tmp/railway/start.sh <role>'
```

To check a blob against this repo, decode it and compare: `echo <blob> | base64 -d | tar xz -C /tmp/check && diff -r /tmp/check .`
(`make-blob.sh` builds a new one.)

| File | Used by | What it does |
|---|---|---|
| `start.sh` | `mastodon` (web), `sidekiq`, `media` | Sets Railway defaults (bucket without ACLs, trusted proxy, no mail until SMTP is set, Puma single mode), derives Web Push (VAPID) keys from `SECRET_KEY_BASE` unless set, waits for Postgres, runs `rails db:prepare`, then starts Puma / Sidekiq / the media proxy |
| `bootstrap.rb` | `mastodon` (web), first start only | Creates the Owner account with `tootctl accounts create`, sets its password from `ADMIN_PASSWORD` and closes registrations. Does nothing once the account exists |
| `media.ru` | `media` | Read-only proxy for the private Railway bucket (Railway buckets can't be public). GET/HEAD by key only, with Range support; no listing, no writes. Mastodon's `S3_ALIAS_HOST` points at it |

The `streaming` service runs the official streaming image unchanged.
