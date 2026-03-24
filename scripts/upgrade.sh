#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/www/server/xagents"
PANEL_DIR="$BASE_DIR/panel"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING_DIR="$(mktemp -d /tmp/xagents-upgrade.XXXXXX)"
BACKUP_DIR="$BASE_DIR/backup"
PORT="${XAGENTS_PORT:-8890}"
NODE_BIN="/usr/bin/node"
NPM_BIN="/usr/bin/npm"
LOCAL_RELEASE_META="$BASE_DIR/release.json"
DEFAULT_REMOTE_MANIFEST_URL="${XAGENTS_REMOTE_MANIFEST_URL:-https://raw.githubusercontent.com/talitonsilva/X-Agents/main/manifest.json}"
STATUS_FILE="${XAGENTS_UPDATE_STATUS_FILE:-$BASE_DIR/runtime/update-status.env}"
LOG_FILE="${XAGENTS_UPDATE_LOG_FILE:-$BASE_DIR/logs/update.log}"
FORCE_UPDATE=0
export PATH="/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin:${PATH:-}"

for arg in "$@"; do
  case "$arg" in
    --force)
      FORCE_UPDATE=1
      ;;
  esac
done

mkdir -p "$(dirname "$STATUS_FILE")" "$(dirname "$LOG_FILE")" "$BACKUP_DIR"
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "========================================"
echo "X-AGENTS by MasterDev Taliton Silva"
echo "Automatic Update Runtime"
echo "========================================"

sanitize_status_value() {
  printf '%s' "${1:-}" | tr '\r\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

write_status() {
  local status="$1"
  local progress="$2"
  local stage="$3"
  local message="$4"
  local current_version="${5:-}"
  local remote_version="${6:-}"
  local tmp_file="${STATUS_FILE}.tmp"
  cat > "$tmp_file" <<EOF
status=$(sanitize_status_value "$status")
progress=$(sanitize_status_value "$progress")
stage=$(sanitize_status_value "$stage")
message=$(sanitize_status_value "$message")
current_version=$(sanitize_status_value "$current_version")
remote_version=$(sanitize_status_value "$remote_version")
updated_at=$(date -Iseconds)
pid=$$
EOF
  mv "$tmp_file" "$STATUS_FILE"
}

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

apt_update_base() {
  apt-get update -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
}

apt_install_packages() {
  if ! apt-get install -y "$@"; then
    apt_update_base
    apt-get install -y "$@"
  fi
}

apt_update_single_source() {
  local source_file="$1"
  apt-get update \
    -o Dir::Etc::sourcelist="$source_file" \
    -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"
}

install_panel_dependencies() {
  if [[ -f "$STAGING_DIR/src/panel/package-lock.json" ]]; then
    "$NPM_BIN" --prefix "$STAGING_DIR/src/panel" ci --omit=dev --legacy-peer-deps
  else
    "$NPM_BIN" --prefix "$STAGING_DIR/src/panel" install --omit=dev --legacy-peer-deps
  fi
}

ensure_sqlite3_runtime() {
  local check_cmd='require("sqlite3"); process.stdout.write("ok")'
  if (cd "$STAGING_DIR/src/panel" && "$NODE_BIN" -e "$check_cmd" >/dev/null 2>&1); then
    return 0
  fi
  echo "[INFO] Recompilando sqlite3 para compatibilidade local ..."
  "$NPM_BIN" --prefix "$STAGING_DIR/src/panel" rebuild sqlite3 --build-from-source
  (cd "$STAGING_DIR/src/panel" && "$NODE_BIN" -e "$check_cmd" >/dev/null 2>&1)
}

ensure_node_22() {
  export DEBIAN_FRONTEND=noninteractive
  apt_install_packages curl wget ca-certificates gnupg
  local node_major=0
  if command -v "$NODE_BIN" >/dev/null 2>&1; then
    node_major="$("$NODE_BIN" -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  elif command -v node >/dev/null 2>&1; then
    node_major="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  fi
  if [[ "${node_major:-0}" -lt 22 ]]; then
    rm -f /etc/apt/sources.list.d/nodesource.list
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list
    apt_update_single_source /etc/apt/sources.list.d/nodesource.list
    apt-get install -y --allow-change-held-packages nodejs
  else
    apt-get install -y nodejs
  fi
  local final_major=0
  if command -v "$NODE_BIN" >/dev/null 2>&1; then
    final_major="$("$NODE_BIN" -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  fi
  if [[ "${final_major:-0}" -lt 22 ]]; then
    echo "[ERRO] Node 22+ e obrigatorio para o X-Agents. Versao atual: $("$NODE_BIN" -v 2>/dev/null || echo 'nao encontrada')"
    write_status "failed" "100" "node" "Node 22+ e obrigatorio" "${LOCAL_VERSION:-}" "${REMOTE_VERSION:-}"
    exit 1
  fi
}

ensure_codex_cli() {
  if ! command -v "$NPM_BIN" >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
  fi
  if ! command -v "$NPM_BIN" >/dev/null 2>&1; then
    echo "[ERRO] npm nao encontrado para instalar o Codex CLI"
    write_status "failed" "100" "codex" "npm nao encontrado para instalar o Codex CLI" "${LOCAL_VERSION:-}" "${REMOTE_VERSION:-}"
    exit 1
  fi
  "$NPM_BIN" install -g @openai/codex
  hash -r
  local codex_bin=""
  local npm_prefix
  local npm_root
  npm_prefix="$("$NPM_BIN" prefix -g 2>/dev/null || true)"
  npm_root="$("$NPM_BIN" root -g 2>/dev/null || true)"
  rm -f /usr/bin/codex
  if [[ -n "${npm_prefix:-}" && -x "${npm_prefix}/bin/codex" ]]; then
    codex_bin="${npm_prefix}/bin/codex"
  elif [[ -n "${npm_prefix:-}" && -x "${npm_prefix}/node_modules/.bin/codex" ]]; then
    codex_bin="${npm_prefix}/node_modules/.bin/codex"
  elif [[ -n "${npm_root:-}" && -x "${npm_root}/@openai/codex/bin/codex.js" ]]; then
    codex_bin="${npm_root}/@openai/codex/bin/codex.js"
  fi
  if [[ -n "${codex_bin:-}" ]]; then
    ln -sf "$codex_bin" /usr/bin/codex
    export PATH="$(dirname "$codex_bin"):/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin"
    hash -r
  fi
  if ! codex --version >/dev/null 2>&1; then
    echo "[ERRO] Codex CLI nao foi encontrado no PATH apos a instalacao"
    write_status "failed" "100" "codex" "Codex CLI nao foi encontrado no PATH apos a instalacao" "${LOCAL_VERSION:-}" "${REMOTE_VERSION:-}"
    exit 1
  fi
}

extract_release_field() {
  local file_path="$1"
  local field_name="$2"
  "$NODE_BIN" -e '
const fs = require("fs");
try {
  const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const value = data?.[process.argv[2]];
  if (value !== undefined && value !== null) process.stdout.write(String(value));
} catch (err) {}
' "$file_path" "$field_name"
}

REMOTE_MANIFEST_URL="$DEFAULT_REMOTE_MANIFEST_URL"
if [[ -f "$LOCAL_RELEASE_META" ]]; then
  saved_manifest_url="$(extract_release_field "$LOCAL_RELEASE_META" "manifestUrl")"
  if [[ -n "${saved_manifest_url:-}" ]]; then
    REMOTE_MANIFEST_URL="$saved_manifest_url"
  fi
fi

LOCAL_VERSION=""
if [[ -f "$LOCAL_RELEASE_META" ]]; then
  LOCAL_VERSION="$(extract_release_field "$LOCAL_RELEASE_META" "version")"
fi

write_status "running" "5" "prepare" "Verificando nova versao" "$LOCAL_VERSION" ""

if [[ "$EUID" -ne 0 ]]; then
  echo "[ERRO] Execute como root"
  write_status "failed" "100" "permissions" "Execute como root" "$LOCAL_VERSION" ""
  exit 1
fi

curl -fsSL "$REMOTE_MANIFEST_URL" -o "$STAGING_DIR/manifest.json"
REMOTE_VERSION="$(extract_release_field "$STAGING_DIR/manifest.json" "version")"
REMOTE_ARCHIVE_URL="$(extract_release_field "$STAGING_DIR/manifest.json" "archiveUrl")"
if [[ -z "${REMOTE_ARCHIVE_URL:-}" ]]; then
  REMOTE_RELEASE_BASE_URL="$(extract_release_field "$STAGING_DIR/manifest.json" "releaseBaseUrl")"
  REMOTE_ARCHIVE_NAME="$(extract_release_field "$STAGING_DIR/manifest.json" "archive")"
  if [[ -n "${REMOTE_RELEASE_BASE_URL:-}" && -n "${REMOTE_ARCHIVE_NAME:-}" ]]; then
    REMOTE_ARCHIVE_URL="${REMOTE_RELEASE_BASE_URL}/${REMOTE_ARCHIVE_NAME}"
  fi
fi

if [[ -z "${REMOTE_VERSION:-}" || -z "${REMOTE_ARCHIVE_URL:-}" ]]; then
  echo "[ERRO] Manifest remoto invalido"
  write_status "failed" "100" "manifest" "Manifest remoto invalido" "$LOCAL_VERSION" "$REMOTE_VERSION"
  exit 1
fi

write_status "running" "10" "check" "Manifest remoto carregado" "$LOCAL_VERSION" "$REMOTE_VERSION"

if [[ "$FORCE_UPDATE" -ne 1 && -n "$LOCAL_VERSION" && "$LOCAL_VERSION" == "$REMOTE_VERSION" ]]; then
  echo "[INFO] X-AGENTS by MasterDev Taliton Silva ja esta na versao mais recente ($LOCAL_VERSION)"
  write_status "no_update" "100" "check" "X-AGENTS by MasterDev Taliton Silva ja esta na versao mais recente" "$LOCAL_VERSION" "$REMOTE_VERSION"
  exit 0
fi

ensure_node_22
ensure_codex_cli
apt_install_packages build-essential python3 make g++

write_status "running" "20" "download" "Baixando pacote da nova versao" "$LOCAL_VERSION" "$REMOTE_VERSION"
curl -fsSL "$REMOTE_ARCHIVE_URL" -o "$STAGING_DIR/xagents.tar.gz"

write_status "running" "30" "extract" "Extraindo pacote da nova versao" "$LOCAL_VERSION" "$REMOTE_VERSION"
mkdir -p "$STAGING_DIR/src"
tar -xzf "$STAGING_DIR/xagents.tar.gz" -C "$STAGING_DIR/src"

write_status "running" "45" "backup" "Gerando backup antes da atualizacao" "$LOCAL_VERSION" "$REMOTE_VERSION"
BACKUP_FILE="$BACKUP_DIR/xagents_preupdate_$(date +%Y%m%d_%H%M%S).tar.gz"
tar --exclude="$BASE_DIR/backup" -czf "$BACKUP_FILE" -C /www/server xagents 2>/dev/null || true

write_status "running" "55" "dependencies" "Instalando dependencias da nova versao" "$LOCAL_VERSION" "$REMOTE_VERSION"
install_panel_dependencies
ensure_sqlite3_runtime

write_status "running" "70" "validate" "Validando arquivos da nova versao" "$LOCAL_VERSION" "$REMOTE_VERSION"
"$NODE_BIN" --check "$STAGING_DIR/src/panel/server.js"
"$NODE_BIN" --check "$STAGING_DIR/src/panel/agentsRuntime.js"
"$NODE_BIN" --check "$STAGING_DIR/src/panel/whatsappRuntime.js"
"$NODE_BIN" --check "$STAGING_DIR/src/panel/public/js/app.js"
"$NODE_BIN" --check "$STAGING_DIR/src/panel/public/js/agents-shell.js"
"$NODE_BIN" --check "$STAGING_DIR/src/panel/public/js/agents.js"

write_status "running" "82" "sync" "Aplicando nova versao no servidor" "$LOCAL_VERSION" "$REMOTE_VERSION"
rsync -a --delete \
  --exclude logs \
  --exclude runtime \
  --exclude backup \
  --exclude tmp \
  --exclude ssl \
  --exclude release \
  --exclude panel/data/panel.db \
  "$STAGING_DIR/src/" "$BASE_DIR/"

write_status "running" "92" "finalize" "Finalizando atualizacao antes do restart do painel" "$LOCAL_VERSION" "$REMOTE_VERSION"
systemctl daemon-reload
systemctl restart xagents-update.timer

echo "X-AGENTS by MasterDev Taliton Silva atualizado com sucesso em :${PORT}"
write_status "completed" "100" "done" "Atualizacao concluida com sucesso. Reiniciando painel" "$REMOTE_VERSION" "$REMOTE_VERSION"
sleep 1
systemctl restart xagents.service
