# Read-only media server for Mastodon's private Railway bucket. It reuses the official Mastodon image
# (pinned by version and digest) for Ruby, Puma and the AWS SDK.
FROM ghcr.io/mastodon/mastodon:v4.7.5@sha256:1cf98fb199f8cc1dcf4bb174095656bd5e19e99f29e935c2a838132083e1f609

COPY media.ru /opt/railway/

CMD ["sh", "-c", "exec bundle exec puma -b tcp://0.0.0.0:${PORT:-3000} -w 0 -t 4:16 -e production /opt/railway/media.ru"]
