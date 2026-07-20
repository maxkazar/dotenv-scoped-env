#!/usr/bin/env bash
#
# install.sh — link dotenv-scoped-env into direnv's plugin directory.
#
# direnv sources every *.sh in $XDG_CONFIG_HOME/direnv/lib/ (default
# ~/.config/direnv/lib/) into each .envrc, so "installing" the plugin is just
# symlinking our lib file there. Idempotent: re-running is safe and only
# refreshes the link.
set -euo pipefail

# Resolve paths relative to this script, so it works regardless of CWD.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_file="$script_dir/lib/dotenv-scoped-env.sh"

lib_dir="${XDG_CONFIG_HOME:-$HOME/.config}/direnv/lib"
target="$lib_dir/dotenv-scoped-env.sh"

mkdir -p "$lib_dir"
ln -sf "$source_file" "$target"

echo "dotenv-scoped-env installed:"
echo "  $target -> $source_file"
echo
echo "Reload your shell (or run 'direnv reload' inside a project) to pick it up."
