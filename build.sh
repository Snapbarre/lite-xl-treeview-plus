#!/usr/bin/env bash

set -e

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: ${CC=gcc}
: ${BIN=libterminal.so}

#CFLAGS="$CFLAGS -fPIC -Ilib/lite-xl/resources/include"
#LDFLAGS=""

#[[ "$@" == "clean" ]] && rm -f *.so *.dll && exit 0
#[[ $OSTYPE != 'msys'* && $CC != *'mingw'* ]] && LDFLAGS="$LDFLAGS -lutil"
#$CC $CFLAGS src/*.c $@ $LDFLAGS -shared -o $BIN

# Define target plugin directory
PLUGIN_DIR="$HOME/.config/lite-xl/plugins/treeview-plus"

if [[ "$1" == "clean" ]]; then
  echo "Cleaning up copied files from $PLUGIN_DIR..."
  rm -f "$PLUGIN_DIR"/*.lua
  # Uncomment if you also want to remove compiled binary
  # rm -f "$PLUGIN_DIR/$BIN"
  echo "Clean finished"
  exit 0
fi

if [ ! -d "$PLUGIN_DIR" ]; then
  mkdir "$PLUGIN_DIR"
fi

# Copy the compiled plugin and init.lua to the plugin directory
#cp "$BIN" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR"/*.lua "$PLUGIN_DIR/"
echo "Build finished"
