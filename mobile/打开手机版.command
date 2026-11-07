#!/bin/bash
set -e
MOBILE_DIR="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/python3 "$MOBILE_DIR/start_mobile.py"
