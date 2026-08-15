#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INSTALL_DIR="${ASCII_INSTALL_DIR:-$HOME/cmds}"

mkdir -p "$INSTALL_DIR"

clang \
    -O2 \
    -fobjc-arc \
    -framework AppKit \
    -framework CoreGraphics \
    "$ROOT/Sources/ascii/main.m" \
    -o "$INSTALL_DIR/ascii"

chmod +x "$INSTALL_DIR/ascii"

echo "Installed ascii to $INSTALL_DIR/ascii"
echo "Try: ascii /path/to/image.png"
