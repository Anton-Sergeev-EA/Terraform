#!/bin/bash
set -euo pipefail
install -m 0755 -d /etc/apt/keyrings
curl -fsSL --retry 5 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
curl -fsSL --retry 5 https://storage.yandexcloud.net/cloud-certs/CA.pem -o /opt/yandex-web/yandex-ca.pem
systemctl daemon-reload
systemctl enable --now yandex-web.service
