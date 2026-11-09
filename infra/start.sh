#!/bin/bash
set -euo pipefail
cd /opt/yandex-web
set -a
source ./settings
set +a

token=$(curl -fsS --max-time 15 -H 'Metadata-Flavor: Google' \
  http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token | jq -er .access_token)
install -m 0700 -d /run/yandex-web
password_file=$(mktemp /run/yandex-web/password.XXXXXX)
export DOCKER_CONFIG
DOCKER_CONFIG=$(mktemp -d /run/yandex-web/docker.XXXXXX)
trap 'rm -f "$password_file" "$DOCKER_CONFIG/config.json"; rmdir "$DOCKER_CONFIG"' EXIT

curl -fsS --max-time 15 -H "Authorization: Bearer $token" \
  "https://payload.lockbox.api.cloud.yandex.net/lockbox/v1/secrets/$SECRET_ID/payload?versionId=$SECRET_VERSION_ID" |
  jq -erj '.entries[] | select(.key == "password") | .textValue | select(length > 0)' > "$password_file"
chown 10001 "$password_file"
mv -f "$password_file" /run/yandex-web/db_password

printf '%s' "$token" | docker login --username iam --password-stdin cr.yandex
docker compose pull
docker compose up -d --force-recreate
