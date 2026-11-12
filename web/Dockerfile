# Mastodon web (Puma) for Railway: the official image, pinned by version and digest, plus a start script.
FROM ghcr.io/mastodon/mastodon:v4.7.5@sha256:1cf98fb199f8cc1dcf4bb174095656bd5e19e99f29e935c2a838132083e1f609

# start.sh sets Railway defaults, prepares the database and starts Puma.
# bootstrap.rb creates the Owner account on the first start only.
COPY start.sh bootstrap.rb /opt/railway/

CMD ["sh", "/opt/railway/start.sh", "web"]
