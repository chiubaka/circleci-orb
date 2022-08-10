#! /usr/bin/env bash

SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"

mkdir -p "$SCRIPT_DIR"
echo "$SCRIPT" > "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
