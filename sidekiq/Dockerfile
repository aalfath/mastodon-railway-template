# Mastodon Sidekiq (background jobs) for Railway: the official image, pinned by version and digest, plus a start script.
FROM ghcr.io/mastodon/mastodon:v4.7.5@sha256:1cf98fb199f8cc1dcf4bb174095656bd5e19e99f29e935c2a838132083e1f609

# Same start.sh as web/; it waits for the web service to load the schema, then starts Sidekiq.
COPY start.sh /opt/railway/

CMD ["sh", "/opt/railway/start.sh", "sidekiq"]
