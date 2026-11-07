#!/bin/bash
set -e
DESKTOP_GAME_DIR="$(cd "$(dirname "$0")" && pwd)"
DESKTOP_GODOT_BIN="${DUSTLINE_GODOT:-/Users/tuotuo/Downloads/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$DESKTOP_GODOT_BIN" ]; then
  echo "未找到 Godot。请用 Godot 打开本文件夹的 project.godot 并按 F5。"
  read -r
  exit 1
fi
exec "$DESKTOP_GODOT_BIN" --path "$DESKTOP_GAME_DIR"
