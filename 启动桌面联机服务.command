#!/bin/bash
set -e
DESKTOP_GAME_DIR="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/python3 "$DESKTOP_GAME_DIR/tools/desktop_online.py"
