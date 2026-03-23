#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/www/server/xagents"
TMP_DIR="$(mktemp -d /tmp/xagents-public-install.XXXXXX)"
VERSION="2026.03.23-r1"
RELEASE_BASE_URL="http://157.173.121.5:8889/static/xagents/releases/2026.03.23-r1"
ARCHIVE_URL="http://157.173.121.5:8889/static/xagents/releases/2026.03.23-r1/xagents-2026.03.23-r1.tar.gz"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ "$EUID" -ne 0 ]]; then
  echo "[ERRO] Execute como root"
  exit 1
fi

echo "[1/4] Baixando release $VERSION ..."
curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/xagents.tar.gz"

echo "[2/4] Extraindo pacote ..."
mkdir -p "$TMP_DIR/src"
tar -xzf "$TMP_DIR/xagents.tar.gz" -C "$TMP_DIR/src"

echo "[3/4] Executando instalador do pacote ..."
cd "$TMP_DIR/src"
bash scripts/install.sh

echo "[4/4] Instalacao concluida em $BASE_DIR"
