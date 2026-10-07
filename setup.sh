#!/usr/bin/env bash
# setup.sh — install or remove the global `devcon` command on this machine.
#
#   ./setup.sh install [--without-devpod]   link devcon into ~/.local/bin, add that to PATH if
#                                           needed, and install DevPod (Homebrew) if missing;
#                                           --without-devpod skips DevPod
#   ./setup.sh uninstall                    remove the command and any PATH line this script added
#
# Safe to re-run. Keep this folder where it is: the command links back here, so
# moving or deleting the folder breaks it (run ./setup.sh install again to fix).
# Uninstall leaves DevPod, Docker, your projects' devcontainer.json files and the
# Claude sign-in volumes alone.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN_DIR="$HOME/.local/bin"
LINK="$BIN_DIR/devcon"
MARKER="# added by devcon setup.sh"

ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
usage() { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; }

shell_rc() {
  case "$(basename "${SHELL:-}")" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) if [[ "$(uname)" == Darwin ]]; then echo "$HOME/.bash_profile"; else echo "$HOME/.bashrc"; fi ;;
    *)    echo "$HOME/.profile" ;;
  esac
}

do_install() {
  local with_devpod=true
  case "${1:-}" in
    --without-devpod) with_devpod=false ;;
    "") ;;
    *) usage; exit 1 ;;
  esac

  # 1. Link the command.
  chmod +x "$HERE/devcon"
  mkdir -p "$BIN_DIR"
  if [[ -e "$LINK" && ! -L "$LINK" ]]; then
    warn "$LINK exists and isn't a link — leaving it alone"; exit 1
  fi
  ln -sf "$HERE/devcon" "$LINK"
  ok "linked $LINK → $HERE/devcon"

  # 2. Make sure ~/.local/bin is on PATH for new shells.
  local rc; rc="$(shell_rc)"
  if [[ ":$PATH:" == *":$BIN_DIR:"* ]] || grep -qs '\.local/bin' "$rc"; then
    ok "$BIN_DIR is already on your PATH"
  else
    printf '\n%s\nexport PATH="$HOME/.local/bin:$PATH"\n' "$MARKER" >> "$rc"
    ok "added $BIN_DIR to PATH in $rc"
    warn "open a new terminal (or run: source $rc) to pick it up"
  fi

  # 3. DevPod (optional) and Docker checks.
  local have_devpod=false
  if command -v devpod >/dev/null 2>&1 || [[ -d /Applications/DevPod.app ]]; then have_devpod=true; fi
  if $with_devpod && ! $have_devpod; then
    if command -v brew >/dev/null 2>&1; then
      brew install --cask devpod && ok "installed DevPod" && have_devpod=true
    else
      warn "Homebrew not found — get DevPod from https://devpod.sh"
    fi
  fi
  $have_devpod && ok "DevPod is installed" \
    || warn "DevPod not installed — run ./setup.sh install, or get it from https://devpod.sh"

  if ! command -v docker >/dev/null 2>&1; then
    warn "Docker not found — install Docker Desktop before creating workspaces"
  elif ! docker info >/dev/null 2>&1; then
    warn "Docker is installed but not running — start Docker Desktop before creating workspaces"
  else
    ok "Docker is running"
  fi

  ok "done — try: devcon help"
}

do_uninstall() {
  if [[ -L "$LINK" ]]; then
    rm "$LINK"; ok "removed $LINK"
  elif [[ -e "$LINK" ]]; then
    warn "$LINK isn't a link this script made — leaving it alone"
  else
    ok "devcon command not installed"
  fi

  # Remove the PATH lines only if this script added them (marker + next line).
  local rc; rc="$(shell_rc)"
  if grep -qsF "$MARKER" "$rc"; then
    local tmp; tmp="$(mktemp)"
    awk -v m="$MARKER" '$0 == m { skip = 1; next } skip { skip = 0; next } { print }' "$rc" > "$tmp"
    cat "$tmp" > "$rc"; rm "$tmp"
    ok "removed the PATH line this script added to $rc"
  fi

  ok "uninstalled — this folder is untouched; delete it yourself if you no longer need it"
}

case "${1:-}" in
  install)   shift; do_install "$@" ;;
  uninstall) do_uninstall ;;
  *) usage; [[ -z "${1:-}" || "$1" == help || "$1" == -h || "$1" == --help ]] || exit 1 ;;
esac
