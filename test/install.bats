#!/usr/bin/env bats
#
# Tests for install.sh — the copy/link installer for the direnv plugin.
#
# Every test isolates the install target by pointing XDG_CONFIG_HOME at a temp
# dir, so nothing touches the real ~/.config/direnv/lib. The "no checkout" and
# download paths are exercised by copying install.sh into a bare temp dir (no
# lib/ beside it) and pointing DSE_RAW_URL at a local file:// source.

setup() {
	WS="$(mktemp -d)"
	export XDG_CONFIG_HOME="$WS/xdg"
	LIBDIR="$XDG_CONFIG_HOME/direnv/lib"
	TARGET="$LIBDIR/dotenv-scoped-env.sh"

	# Canonical path (no ..) so it matches the symlink target install.sh writes.
	REPO="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	INSTALL="$REPO/install.sh"
	PLUGIN="$REPO/lib/dotenv-scoped-env.sh"

	# A standalone copy of install.sh with NO lib/ beside it, to exercise the
	# "piped / no checkout" download path.
	STANDALONE_DIR="$WS/standalone"
	mkdir -p "$STANDALONE_DIR"
	cp "$INSTALL" "$STANDALONE_DIR/install.sh"

	# A fake plugin served over file:// so download tests need no network. It must
	# define dotenv_scoped_env() or install.sh's content check rejects it.
	FAKE="$WS/fake-plugin.sh"
	printf '# FAKE PLUGIN MARKER\ndotenv_scoped_env() { :; }\n' >"$FAKE"
}

teardown() {
	rm -rf "$WS"
}

@test "default copy from checkout installs a regular file matching lib/" {
	run bash "$INSTALL"
	[ "$status" -eq 0 ]
	[ -f "$TARGET" ]
	[ ! -L "$TARGET" ]
	# Content is byte-identical to the source plugin.
	run diff "$PLUGIN" "$TARGET"
	[ "$status" -eq 0 ]
}

@test "copy from checkout prefers the local file over an available download" {
	# A download source is offered, but the checkout must win — proving the
	# local-file precedence, not just that *some* file lands.
	DSE_RAW_URL="file://$FAKE" run bash "$INSTALL"
	[ "$status" -eq 0 ]
	run cat "$TARGET"
	[[ "$output" != *"FAKE PLUGIN MARKER"* ]]
	run diff "$PLUGIN" "$TARGET"
	[ "$status" -eq 0 ]
}

@test "re-running the copy install is idempotent and refreshes content" {
	bash "$INSTALL"
	# Corrupt the installed copy, then reinstall — it must be restored.
	printf 'stale\n' >"$TARGET"
	run bash "$INSTALL"
	[ "$status" -eq 0 ]
	run diff "$PLUGIN" "$TARGET"
	[ "$status" -eq 0 ]
}

@test "--update behaves like the default copy install" {
	mkdir -p "$LIBDIR"
	printf 'stale\n' >"$TARGET"
	run bash "$INSTALL" --update
	[ "$status" -eq 0 ]
	[ ! -L "$TARGET" ]
	run diff "$PLUGIN" "$TARGET"
	[ "$status" -eq 0 ]
}

@test "no checkout beside script downloads from DSE_RAW_URL" {
	DSE_RAW_URL="file://$FAKE" run bash "$STANDALONE_DIR/install.sh"
	[ "$status" -eq 0 ]
	[ -f "$TARGET" ]
	[ ! -L "$TARGET" ]
	run cat "$TARGET"
	[[ "$output" == *"FAKE PLUGIN MARKER"* ]]
}

@test "--remote forces download even inside a checkout" {
	DSE_RAW_URL="file://$FAKE" run bash "$INSTALL" --remote
	[ "$status" -eq 0 ]
	run cat "$TARGET"
	# The downloaded fake content wins over the local checkout file.
	[[ "$output" == *"FAKE PLUGIN MARKER"* ]]
}

@test "a garbage download (no plugin function) is rejected" {
	printf '<html>captive portal</html>\n' >"$WS/garbage"
	DSE_RAW_URL="file://$WS/garbage" run bash "$STANDALONE_DIR/install.sh"
	[ "$status" -ne 0 ]
	[[ "$output" == *"not the plugin"* ]]
	[ ! -e "$TARGET" ]
}

@test "a failed download leaves an already-installed plugin intact" {
	# Install a good copy first, then attempt an update from a missing source.
	bash "$INSTALL"
	DSE_RAW_URL="file://$WS/does-not-exist" run bash "$INSTALL" --remote
	[ "$status" -ne 0 ]
	# The previously installed plugin is untouched.
	run diff "$PLUGIN" "$TARGET"
	[ "$status" -eq 0 ]
}

@test "copy after --link replaces the symlink without clobbering the repo file" {
	# Snapshot the repo plugin so we can prove it is never written through.
	before="$(cat "$PLUGIN")"

	bash "$INSTALL" --link
	[ -L "$TARGET" ]

	# Now a plain copy install must replace the symlink with a regular file...
	run bash "$INSTALL"
	[ "$status" -eq 0 ]
	[ ! -L "$TARGET" ]
	# ...and the repo's tracked source file must be unchanged.
	[ "$(cat "$PLUGIN")" = "$before" ]
}

@test "--link creates a symlink pointing at the checkout plugin" {
	run bash "$INSTALL" --link
	[ "$status" -eq 0 ]
	[ -L "$TARGET" ]
	# Symlink resolves to the repo's plugin file.
	[ "$(readlink "$TARGET")" = "$PLUGIN" ]
}

@test "--link without a checkout fails cleanly" {
	run bash "$STANDALONE_DIR/install.sh" --link
	[ "$status" -ne 0 ]
	[[ "$output" == *"--link needs a local checkout"* ]]
	[ ! -e "$TARGET" ]
}

@test "--link and --remote together are rejected" {
	run bash "$INSTALL" --link --remote
	[ "$status" -ne 0 ]
	[[ "$output" == *"mutually exclusive"* ]]
	[ ! -e "$TARGET" ]
}

@test "--help and -h print usage and exit 0" {
	run bash "$INSTALL" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage: install.sh"* ]]

	run bash "$INSTALL" -h
	[ "$status" -eq 0 ]
	[[ "$output" == *"Usage: install.sh"* ]]
}

@test "unknown option fails with usage" {
	run bash "$INSTALL" --bogus
	[ "$status" -ne 0 ]
	[[ "$output" == *"unknown option"* ]]
}
