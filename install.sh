#!/usr/bin/env bash
#
# install.sh — install (or update) dotenv-scoped-env into direnv's plugin dir.
#
# direnv sources every *.sh in $XDG_CONFIG_HOME/direnv/lib/ (default
# ~/.config/direnv/lib/) into each .envrc, so "installing" the plugin just means
# putting our one library file there.
#
# Two modes:
#
#   (default)   Copy the plugin file into the lib dir. Self-contained — no repo
#               checkout needed afterwards. Works when piped straight from the
#               web (`curl -fsSL …/install.sh | bash`): with no checkout to copy
#               from, the file is downloaded instead. Re-running simply refreshes
#               the copy, so it doubles as "update".
#
#   --link      Symlink the plugin file from a local checkout (for contributors).
#               `git pull` then updates the plugin in place. Requires a checkout.
#
# Other flags:
#   --remote    Force downloading the plugin even inside a checkout.
#   --update    Alias for the default copy behavior (reads better in docs).
#   -h, --help  Print usage and exit.
#
# Environment overrides (mainly for testing / mirrors):
#   DSE_REF      git ref used to build the download URL (default: main).
#   DSE_RAW_URL  full source URL, overrides the constructed one. Supports
#                file:// URLs (curl only), so the download path is testable
#                without network.
set -euo pipefail

# Resolve paths relative to this script, so it works regardless of CWD.
script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# Only trust a local checkout when we know where this script lives. Piped via
# `curl | bash`, BASH_SOURCE[0] is empty; we deliberately do NOT fall back to a
# CWD-relative path (that would copy a stray lib/ from wherever the user stood).
# So copy mode downloads, and --link errors out, when script_dir is unknown.
source_file=""
if [ -n "$script_dir" ]; then
	source_file="$script_dir/lib/dotenv-scoped-env.sh"
fi

lib_dir="${XDG_CONFIG_HOME:-$HOME/.config}/direnv/lib"
target="$lib_dir/dotenv-scoped-env.sh"

usage() {
	cat <<'EOF'
Usage: install.sh [--link | --remote | --update | --help]

  (no flags)  Install/update by copying the plugin into direnv's lib dir.
              Downloads the file if run without a local checkout (curl | bash).
  --link      Symlink the plugin from this checkout (for contributors).
  --remote    Force downloading the plugin even inside a checkout.
  --update    Alias for the default copy behavior.
  -h, --help  Show this help.

Env: DSE_REF (default: main), DSE_RAW_URL (overrides the download URL).
EOF
}

# Print the plugin file's contents to stdout, fetched from the (overridable) URL.
download() {
	local url="${DSE_RAW_URL:-https://raw.githubusercontent.com/maxkazar/dotenv-scoped-env/${DSE_REF:-main}/lib/dotenv-scoped-env.sh}"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url"
	elif command -v wget >/dev/null 2>&1; then
		wget -qO- "$url"
	else
		echo "install.sh: need curl or wget to download the plugin" >&2
		return 1
	fi
}

mode="copy"
force_remote=false
while [ "$#" -gt 0 ]; do
	case "$1" in
		--link) mode="link" ;;
		--remote) force_remote=true ;;
		--update) mode="copy" ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "install.sh: unknown option '$1'" >&2
			usage >&2
			exit 2
			;;
	esac
	shift
done

if [ "$mode" = "link" ] && [ "$force_remote" = true ]; then
	echo "install.sh: --link and --remote are mutually exclusive." >&2
	exit 2
fi

mkdir -p "$lib_dir"

if [ "$mode" = "link" ]; then
	# Symlink mode needs the file on disk; a piped run has no checkout.
	if [ ! -f "$source_file" ]; then
		echo "install.sh: --link needs a local checkout, but the plugin file was not found." >&2
		echo "install.sh: clone the repo and run ./install.sh --link from it, or drop --link to copy." >&2
		exit 1
	fi
	# -n: don't dereference an existing symlink-to-dir at $target; -f: overwrite.
	ln -sfn "$source_file" "$target"
	echo "dotenv-scoped-env linked:"
	echo "  $target -> $source_file"
else
	# Stage into $lib_dir, then rename over $target. The rename is atomic (same
	# filesystem) and REPLACES an existing symlink — so a copy/--remote after a
	# prior --link never writes through the symlink into the repo checkout, and
	# a failed download never truncates an already-installed plugin.
	staged="$(mktemp "$lib_dir/.dotenv-scoped-env.XXXXXX")"
	trap 'rm -f "$staged"' EXIT INT TERM

	if [ "$force_remote" = false ] && [ -f "$source_file" ]; then
		cp "$source_file" "$staged"
		origin="copied from checkout"
	else
		download >"$staged"
		origin="downloaded"
	fi

	# Reject a "successful" but useless payload (empty body, captive-portal HTML,
	# truncated file): the installed file must define the function direnv calls.
	if ! grep -q 'dotenv_scoped_env()' "$staged"; then
		echo "install.sh: fetched file is not the plugin (no dotenv_scoped_env definition); aborting." >&2
		exit 1
	fi

	mv -f "$staged" "$target"
	trap - EXIT INT TERM
	echo "dotenv-scoped-env installed ($origin):"
	echo "  $target"
fi

echo
echo "Reload your shell (or run 'direnv reload' inside a project) to pick it up."
