#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/www/server/xagents"
PANEL_DIR="$BASE_DIR/panel"
LOG_DIR="$BASE_DIR/logs"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT="${XAGENTS_PORT:-8890}"
NODE_BIN="/usr/bin/node"
NPM_BIN="/usr/bin/npm"
export PATH="/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin:${PATH:-}"

if [[ -t 1 ]]; then
  C_RESET="$(printf '\033[0m')"
  C_BLUE="$(printf '\033[38;5;39m')"
  C_CYAN="$(printf '\033[38;5;51m')"
  C_GREEN="$(printf '\033[38;5;46m')"
  C_GOLD="$(printf '\033[38;5;220m')"
else
  C_RESET=""
  C_BLUE=""
  C_CYAN=""
  C_GREEN=""
  C_GOLD=""
fi

print_banner() {
  printf "%b\n" "${C_BLUE}██╗  ██╗       █████╗  ██████╗ ███████╗███╗   ██╗████████╗███████╗${C_RESET}"
  printf "%b\n" "${C_CYAN}╚██╗██╔╝      ██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝██╔════╝${C_RESET}"
  printf "%b\n" "${C_GREEN} ╚███╔╝ █████╗███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║   ███████╗${C_RESET}"
  printf "%b\n" "${C_CYAN} ██╔██╗ ╚════╝██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║   ╚════██║${C_RESET}"
  printf "%b\n" "${C_BLUE}██╔╝ ██╗      ██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║   ███████║${C_RESET}"
  printf "%b\n" "${C_CYAN}╚═╝  ╚═╝      ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝${C_RESET}"
  printf "%b\n" "${C_GOLD}                 Master Dev Taliton Silva${C_RESET}"
}

print_progress() {
  local percent="$1"
  local label="$2"
  local width=34
  local filled=$((percent * width / 100))
  local empty=$((width - filled))
  local fill_bar empty_bar
  fill_bar=$(printf '%*s' "$filled" '')
  empty_bar=$(printf '%*s' "$empty" '')
  fill_bar=${fill_bar// /#}
  empty_bar=${empty_bar// /-}
  printf "%b[%s%s]%b %3d%%  %s\n" "${C_CYAN}" "$fill_bar" "$empty_bar" "${C_RESET}" "$percent" "$label"
}

STEP_LOG_DIR="$(mktemp -d /tmp/xagents-install-logs.XXXXXX)"
LAST_LOG_FILE=""

cleanup_install_logs() {
  rm -rf "$STEP_LOG_DIR"
}

trap cleanup_install_logs EXIT

run_logged() {
  local name="$1"
  shift
  LAST_LOG_FILE="$STEP_LOG_DIR/${name//[^a-zA-Z0-9._-]/_}.log"
  if "$@" >"$LAST_LOG_FILE" 2>&1; then
    rm -f "$LAST_LOG_FILE"
    LAST_LOG_FILE=""
    return 0
  fi
  return 1
}

fail_with_last_log() {
  local label="$1"
  echo "[ERRO] Falha em: $label"
  if [[ -n "${LAST_LOG_FILE:-}" && -f "$LAST_LOG_FILE" ]]; then
    echo "----- log da etapa -----"
    cat "$LAST_LOG_FILE"
    echo "------------------------"
  fi
  exit 1
}

apt_update_base() {
  run_logged apt_update_base apt-get update -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" \
    || fail_with_last_log "apt update"
}

apt_install_packages() {
  if ! run_logged apt_install_packages apt-get install -y "$@"; then
    apt_update_base
    run_logged apt_install_packages_retry apt-get install -y "$@" || fail_with_last_log "instalacao de pacotes"
  fi
}

apt_update_single_source() {
  local source_file="$1"
  run_logged apt_update_single_source \
    apt-get update \
    -o Dir::Etc::sourcelist="$source_file" \
    -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"
  [[ -z "${LAST_LOG_FILE:-}" ]] || fail_with_last_log "apt update da fonte $source_file"
}

install_panel_dependencies() {
  if [[ -f "$PANEL_DIR/package-lock.json" ]]; then
    run_logged npm_ci "$NPM_BIN" --prefix "$PANEL_DIR" ci --omit=dev --legacy-peer-deps \
      || fail_with_last_log "npm ci do painel"
  else
    run_logged npm_install "$NPM_BIN" --prefix "$PANEL_DIR" install --omit=dev --legacy-peer-deps \
      || fail_with_last_log "npm install do painel"
  fi
}

ensure_sqlite3_runtime() {
  local check_cmd='require("sqlite3"); process.stdout.write("ok")'
  if (cd "$PANEL_DIR" && "$NODE_BIN" -e "$check_cmd" >/dev/null 2>&1); then
    return 0
  fi
  echo "[INFO] Recompilando sqlite3 para compatibilidade local ..."
  run_logged npm_rebuild_sqlite3 "$NPM_BIN" --prefix "$PANEL_DIR" rebuild sqlite3 --build-from-source \
    || fail_with_last_log "rebuild do sqlite3"
  (cd "$PANEL_DIR" && "$NODE_BIN" -e "$check_cmd" >/dev/null 2>&1)
}

ensure_node_22() {
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
    run_logged apt_install_nodejs apt-get install -y --allow-change-held-packages nodejs \
      || fail_with_last_log "instalacao do Node.js"
  else
    run_logged apt_install_nodejs apt-get install -y nodejs || fail_with_last_log "instalacao do Node.js"
  fi

  local final_major=0
  if command -v "$NODE_BIN" >/dev/null 2>&1; then
    final_major="$("$NODE_BIN" -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
  fi
  if [[ "${final_major:-0}" -lt 22 ]]; then
    echo "[ERRO] Node 22+ e obrigatorio para o X-Agents. Versao atual: $("$NODE_BIN" -v 2>/dev/null || echo 'nao encontrada')"
    exit 1
  fi
}

ensure_codex_cli() {
  if ! command -v "$NPM_BIN" >/dev/null 2>&1; then
    corepack enable >/dev/null 2>&1 || true
  fi
  if ! command -v "$NPM_BIN" >/dev/null 2>&1; then
    echo "[ERRO] npm nao encontrado para instalar o Codex CLI"
    exit 1
  fi
  run_logged npm_install_codex "$NPM_BIN" install -g @openai/codex || fail_with_last_log "instalacao do Codex CLI"
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
    echo "[DEBUG] npm prefix -g: $("$NPM_BIN" prefix -g 2>/dev/null || echo 'indisponivel')"
    echo "[DEBUG] npm root -g: $("$NPM_BIN" root -g 2>/dev/null || echo 'indisponivel')"
    exit 1
  fi
}

if [[ "$EUID" -ne 0 ]]; then
  echo "[ERRO] Execute como root"
  exit 1
fi

print_banner
print_progress 5 "Preparando ambiente"

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

print_progress 15 "Instalando dependencias base"
apt_install_packages git sqlite3 rsync certbot python3-certbot-dns-cloudflare zip unzip tar gzip bzip2 xz-utils build-essential python3 make g++
print_progress 30 "Validando Node.js 22+"
ensure_node_22
print_progress 42 "Instalando Codex CLI"
ensure_codex_cli

systemctl stop xagents.service 2>/dev/null || true
systemctl stop xagents-update.timer 2>/dev/null || true
systemctl stop xagents-update.service 2>/dev/null || true
pkill -f "/www/server/xagents/panel/server.js" 2>/dev/null || true
systemctl reset-failed xagents.service 2>/dev/null || true

print_progress 55 "Sincronizando arquivos do painel"
mkdir -p \
  "$BASE_DIR/panel/data" \
  "$BASE_DIR/runtime/secrets" \
  "$BASE_DIR/runtime/agents" \
  "$BASE_DIR/runtime/whatsapp" \
  "$BASE_DIR/runtime/whisper" \
  "$BASE_DIR/logs" \
  "$BASE_DIR/backup" \
  "$BASE_DIR/tmp"

rsync -a \
  --exclude .git \
  --exclude node_modules \
  --exclude logs \
  --exclude runtime \
  --exclude backup \
  --exclude tmp \
  --exclude ssl \
  --exclude release \
  --exclude panel/data/panel.db \
  "$SRC_DIR/" "$BASE_DIR/"

chmod +x "$BASE_DIR/scripts/"*.sh 2>/dev/null || true

rm -rf "$LOG_DIR"/*
rm -rf "$BASE_DIR/tmp"/*
find "$BASE_DIR/runtime" -type f -name "*.log" -delete 2>/dev/null || true

print_progress 72 "Instalando dependencias do painel"
install_panel_dependencies
print_progress 82 "Validando runtime local"
ensure_sqlite3_runtime

"$NODE_BIN" --check "$PANEL_DIR/server.js"
"$NODE_BIN" --check "$PANEL_DIR/agentsRuntime.js"
"$NODE_BIN" --check "$PANEL_DIR/whatsappRuntime.js"
"$NODE_BIN" --check "$PANEL_DIR/public/js/app.js"
"$NODE_BIN" --check "$PANEL_DIR/public/js/agents-shell.js"
"$NODE_BIN" --check "$PANEL_DIR/public/js/agents.js"

if [[ -s "$PANEL_DIR/config.json" ]]; then
  SESSION_SECRET="$("$NODE_BIN" -e "try{const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));if(c&&c.sessionSecret)process.stdout.write(String(c.sessionSecret));}catch(e){}" "$PANEL_DIR/config.json")"
fi
if [[ -z "${SESSION_SECRET:-}" ]]; then
  SESSION_SECRET="$("$NODE_BIN" -e "console.log(require('crypto').randomBytes(48).toString('hex'))")"
fi
cat > "$PANEL_DIR/config.json" <<CFG
{
  "sessionSecret": "$SESSION_SECRET"
}
CFG
chmod 600 "$PANEL_DIR/config.json"

HAS_ADMIN=0
if [[ -f "$PANEL_DIR/data/panel.db" ]]; then
  ADMIN_COUNT="$(sqlite3 "$PANEL_DIR/data/panel.db" "SELECT COUNT(*) FROM users WHERE username='admin';" 2>/dev/null || true)"
  if [[ "${ADMIN_COUNT:-0}" =~ ^[0-9]+$ ]] && [[ "${ADMIN_COUNT:-0}" -gt 0 ]]; then
    HAS_ADMIN=1
  fi
fi

if [[ "$HAS_ADMIN" -eq 1 ]]; then
  "$NODE_BIN" "$PANEL_DIR/migrate.js"
  ADMIN_USER="admin"
  ADMIN_PASS=""
else
  ADMIN_USER="admin"
  ADMIN_PASS="$("$NODE_BIN" -e "const c='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%^*_+=';const b=require('crypto').randomBytes(32);let o='';for(let i=0;i<16;i++)o+=c[b[i]%c.length];console.log(o)")"
  ADMIN_PASS_HASH="$(cd "$PANEL_DIR" && "$NODE_BIN" -e "const b=require('bcryptjs'); console.log(b.hashSync(process.argv[1], 10));" "$ADMIN_PASS")"
  ADMIN_USER="$ADMIN_USER" ADMIN_PASS_HASH="$ADMIN_PASS_HASH" "$NODE_BIN" "$PANEL_DIR/migrate.js"
fi

print_progress 92 "Configurando servicos systemd"
cat > /etc/systemd/system/xagents.service <<UNIT
[Unit]
Description=X-Agents Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=$PANEL_DIR
Environment=XAGENTS_PORT=$PORT
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/usr/bin/node $PANEL_DIR/server.js
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/xagents-update.service <<UNIT
[Unit]
Description=X-Agents Scheduled Update
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$BASE_DIR
Environment=PATH=/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/sbin:/bin
ExecStart=/usr/bin/bash $BASE_DIR/scripts/update.sh
User=root
UNIT

cat > /etc/systemd/system/xagents-update.timer <<UNIT
[Unit]
Description=Run X-Agents automatic update daily

[Timer]
OnBootSec=15m
OnUnitActiveSec=24h
RandomizedDelaySec=45m
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
run_logged systemctl_enable_xagents systemctl enable xagents.service || fail_with_last_log "habilitacao do xagents.service"
run_logged systemctl_enable_timer systemctl enable xagents-update.timer || fail_with_last_log "habilitacao do xagents-update.timer"
run_logged systemctl_restart_xagents systemctl restart xagents.service || fail_with_last_log "reinicio do xagents.service"
run_logged systemctl_restart_timer systemctl restart xagents-update.timer || fail_with_last_log "reinicio do xagents-update.timer"

if command -v ufw >/dev/null 2>&1 && ufw status | grep -qi "Status: active"; then
  ufw allow "${PORT}/tcp" || true
fi

IP_ADDR="$(hostname -I | awk '{print $1}')"
print_progress 100 "Instalacao concluida"
if [[ -n "${ADMIN_PASS:-}" ]]; then
  echo "========================================"
  echo "X-AGENTS by MasterDev Taliton Silva"
  echo "Instalacao concluida com sucesso"
  echo "URL: http://${IP_ADDR}:${PORT}"
  echo "Usuario: ${ADMIN_USER}"
  echo "Senha: ${ADMIN_PASS}"
  echo "========================================"
else
  echo "========================================"
  echo "X-AGENTS by MasterDev Taliton Silva"
  echo "Atualizacao/reinstalacao concluida"
  echo "URL: http://${IP_ADDR}:${PORT}"
  echo "Usuario: admin"
  echo "Senha: preservada"
  echo "========================================"
fi

cleanup_install_logs
