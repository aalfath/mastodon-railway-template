#!/bin/sh
# Mastodon on Railway: one start script for the web, sidekiq and media services.
# Usage: start.sh web|sidekiq|media   (the image's working dir is /opt/mastodon)
set -e
cd /opt/mastodon
role="$1"
log() { echo "[railway] $*"; }

export RAILS_ENV=production NODE_ENV=production RAILS_LOG_TO_STDOUT=enabled
export RAILS_SERVE_STATIC_FILES="${RAILS_SERVE_STATIC_FILES:-true}"
export WEB_CONCURRENCY="${WEB_CONCURRENCY:-0}" MAX_THREADS="${MAX_THREADS:-5}"
# Railway's edge replaces X-Forwarded-For with "client, edge" and connects from
# 100.64.0.0/10, so every hop is trusted and Mastodon takes the client IP.
export TRUSTED_PROXY_IP="${TRUSTED_PROXY_IP:-0.0.0.0/0,::/0}"
# Media goes to the Railway bucket. It is private, so no ACL is sent and the
# media service below serves the files on S3_ALIAS_HOST.
export S3_ENABLED="${S3_ENABLED:-true}" S3_PROTOCOL=https
export S3_PERMISSION="${S3_PERMISSION-}"
export S3_HOSTNAME="${S3_HOSTNAME:-$(echo "$S3_ENDPOINT" | sed -e 's#^[a-z]*://##' -e 's#/.*##')}"
export ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
# Optional settings arrive as references that may resolve to "": drop empty ones
# so Mastodon's defaults apply (SMTP stays off until SMTP_SERVER is set).
for v in SMTP_SERVER SMTP_PORT SMTP_LOGIN SMTP_PASSWORD SMTP_FROM_ADDRESS SMTP_AUTH_METHOD SMTP_OPENSSL_VERIFY_MODE SMTP_ENABLE_STARTTLS VAPID_PRIVATE_KEY VAPID_PUBLIC_KEY; do
  eval "[ -n \"\${$v}\" ] || unset $v"
done
if [ -n "$SMTP_SERVER" ]; then
  export SMTP_FROM_ADDRESS="${SMTP_FROM_ADDRESS:-notifications@$LOCAL_DOMAIN}"
else
  export SMTP_DELIVERY_METHOD="${SMTP_DELIVERY_METHOD:-test}" # no SMTP yet: e-mails are dropped, not retried
fi

# Web Push (VAPID) needs an EC P-256 key pair, which ${{secret()}} can't make.
# Unless both keys are set, derive a stable pair from SECRET_KEY_BASE.
if [ "$role" != media ] && { [ -z "$VAPID_PRIVATE_KEY" ] || [ -z "$VAPID_PUBLIC_KEY" ]; }; then
  eval "$(ruby -ropenssl -rbase64 -e '
    g = OpenSSL::PKey::EC::Group.new("prime256v1")
    d = OpenSSL::BN.new(OpenSSL::Digest::SHA256.hexdigest("mastodon-vapid:" + ENV.fetch("SECRET_KEY_BASE")), 16) % (g.order - 1) + 1
    priv = d.to_s(2).rjust(32, "\0")
    pub = g.generator.mul(d).to_octet_string(:uncompressed)
    puts "export VAPID_PRIVATE_KEY=#{Base64.urlsafe_encode64(priv)} VAPID_PUBLIC_KEY=#{Base64.urlsafe_encode64(pub)}"')"
fi

wait_for() { # wait_for <ruby check> <what>
  i=0
  until bundle exec ruby -rpg -e "$1" >/dev/null 2>&1; do
    i=$((i + 1)); [ "$i" -ge 120 ] && { log "gave up waiting for $2"; exit 1; }
    log "waiting for $2 ($i)"; sleep 5
  done
}

case "$role" in
  web)
    wait_for 'PG.connect(ENV.fetch("DATABASE_URL")).exec("select 1")' Postgres
    log "preparing the database (schema load on first start, migrations after upgrades)"
    bundle exec rails db:prepare
    bundle exec rails runner /tmp/railway/bootstrap.rb
    exec bundle exec puma -C config/puma.rb
    ;;
  sidekiq)
    wait_for 'PG.connect(ENV.fetch("DATABASE_URL")).exec("select 1 from accounts limit 1")' "the web service to load the schema"
    exec bundle exec sidekiq
    ;;
  media)
    exec bundle exec puma -b "tcp://0.0.0.0:${PORT:-3000}" -w 0 -t 4:16 -e production /tmp/railway/media.ru
    ;;
  *) log "unknown role '$role'"; exit 64 ;;
esac
