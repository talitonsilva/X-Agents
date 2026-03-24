#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/www/server/xagents"

systemctl stop xagents.service 2>/dev/null || true
systemctl stop xagents-update.timer 2>/dev/null || true
systemctl stop xagents-update.service 2>/dev/null || true
systemctl disable --now xagents.service 2>/dev/null || true
systemctl disable --now xagents-update.timer 2>/dev/null || true
systemctl disable --now xagents-update.service 2>/dev/null || true
pkill -f "/www/server/xagents/panel/server.js" 2>/dev/null || true
pkill -f "xagents.service" 2>/dev/null || true
rm -f /etc/systemd/system/xagents.service
rm -f /etc/systemd/system/xagents-update.service
rm -f /etc/systemd/system/xagents-update.timer
systemctl daemon-reload
systemctl reset-failed xagents.service 2>/dev/null || true
rm -rf "$BASE_DIR"

echo "X-Agents removido por completo."
echo "Diretorio apagado: $BASE_DIR"
