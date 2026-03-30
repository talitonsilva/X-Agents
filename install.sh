#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/www/server/xagents"
TMP_DIR="$(mktemp -d /tmp/xagents-public-install.XXXXXX)"
VERSION="2026.03.31-r27"
RELEASE_BASE_URL="https://github.com/talitonsilva/X-Agents/releases/download/2026.03.31-r27"
ARCHIVE_URL="https://github.com/talitonsilva/X-Agents/releases/download/2026.03.31-r27/xagents-2026.03.31-r27.tar.gz"

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

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ "$EUID" -ne 0 ]]; then
  echo "[ERRO] Execute como root"
  exit 1
fi

print_banner
print_progress 5 "Preparando auto instalador"
echo "[1/4] Baixando release $VERSION ..."
curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/xagents.tar.gz"

print_progress 35 "Release baixada"
echo "[2/4] Extraindo pacote ..."
mkdir -p "$TMP_DIR/src"
tar -xzf "$TMP_DIR/xagents.tar.gz" -C "$TMP_DIR/src"

print_progress 60 "Pacote extraido"
echo "[3/4] Executando instalador do pacote ..."
cd "$TMP_DIR/src"
bash scripts/install.sh

print_progress 100 "Instalacao finalizada"
echo "[4/4] Instalacao concluida em $BASE_DIR"
