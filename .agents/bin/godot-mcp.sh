#!/usr/bin/env bash
# godot-mcp launcher — shared by OpenCode and DeepSeek Harness (see .agents/README.md).
#
# Speaks MCP over stdio, so nothing may be written to stdout except the protocol.
# Everything diagnostic goes to stderr.
#
# Environment:
#   GODOT_MCP_HOME  install dir of godot-mcp (default: ~/.local/share/godot-mcp)
#   GODOT_PATH      Godot executable; auto-resolved when unset
#   GODOT_MCP_ALLOWED_DIRS  optional root allowlist enforced by the server
set -euo pipefail

INSTALL_DIR="${GODOT_MCP_HOME:-$HOME/.local/share/godot-mcp}"
ENTRY="$INSTALL_DIR/build/index.js"

if [[ ! -f "$ENTRY" ]]; then
  echo "godot-mcp: entry not found: $ENTRY" >&2
  echo "godot-mcp: install it first (see .agents/README.md)" >&2
  exit 1
fi

resolve_godot() {
  local candidate
  if [[ -n "${GODOT_PATH:-}" && -x "${GODOT_PATH}" ]]; then
    printf '%s\n' "$GODOT_PATH"
    return 0
  fi
  for candidate in \
    "$HOME/App/Godot/Godot_v4.7.2-stable_linux.x86_64" \
    "$HOME/App/Godot/Godot_v4.6.1-stable_linux.x86_64" \
    "$(command -v godot 2>/dev/null || true)" \
    "$(command -v godot4 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if godot_bin="$(resolve_godot)"; then
  export GODOT_PATH="$godot_bin"
else
  echo "godot-mcp: no Godot executable found; set GODOT_PATH" >&2
fi

exec node "$ENTRY" "$@"
