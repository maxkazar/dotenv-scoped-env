#!/usr/bin/env bats
#
# Tests for the dotenv_scoped_env direnv plugin function.
#
# direnv's `dotenv_if_exists` is not available outside direnv, so we stub it to
# record which existing files the function asks to load, in order. Each test
# runs from a nested subdirectory to exercise the walk-up-the-tree lookup.

setup() {
	WS="$(mktemp -d)"

	mkdir -p "$WS/envs/default" "$WS/envs/staging" "$WS/project/nested"
	: >"$WS/envs/default/.env"
	: >"$WS/envs/default/.env.mcp"
	: >"$WS/envs/default/.env.local"
	: >"$WS/envs/staging/.env"

	# Stub direnv's builtin: emit "LOAD:<basename>" for files that exist, so
	# tests can assert both which files were requested and in what order.
	dotenv_if_exists() {
		[ -f "$1" ] && echo "LOAD:$(basename "$1")"
		return 0
	}

	# shellcheck source=../lib/dotenv-scoped-env.sh
	source "${BATS_TEST_DIRNAME}/../lib/dotenv-scoped-env.sh"

	cd "$WS/project/nested"
}

teardown() {
	rm -rf "$WS"
}

@test "default call loads .env then .env.mcp from envs/default" {
	run dotenv_scoped_env
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "LOAD:.env" ]
	[ "${lines[1]}" = "LOAD:.env.mcp" ]
	[ "${#lines[@]}" -eq 2 ]
}

@test "scope-only call resolves the named scope with default file list" {
	run dotenv_scoped_env staging
	[ "$status" -eq 0 ]
	# staging only has .env; .env.mcp is skipped as missing.
	[ "${lines[0]}" = "LOAD:.env" ]
	[ "${#lines[@]}" -eq 1 ]
}

@test "explicit file list overrides the default and preserves order" {
	run dotenv_scoped_env default .env .env.local
	[ "$status" -eq 0 ]
	[ "${lines[0]}" = "LOAD:.env" ]
	[ "${lines[1]}" = "LOAD:.env.local" ]
	# .env.mcp must NOT be loaded when an explicit list is given.
	[ "${#lines[@]}" -eq 2 ]
}

@test "missing scope warns on stderr and returns success" {
	run dotenv_scoped_env nonexistent
	[ "$status" -eq 0 ]

	# The warning must go to stderr, not stdout. Capture each stream separately
	# rather than trusting run's merged $output.
	stderr_only="$(dotenv_scoped_env nonexistent 2>&1 1>/dev/null)"
	stdout_only="$(dotenv_scoped_env nonexistent 2>/dev/null)"
	[[ "$stderr_only" == *"envs/nonexistent not found up the tree"* ]]
	[ -z "$stdout_only" ]
}

@test "walk-up selects the nearest ancestor holding envs/<scope>" {
	# A closer envs/default (only .env) shadows the farther one (.env + .env.mcp).
	mkdir -p "$WS/project/envs/default"
	: >"$WS/project/envs/default/.env"

	run dotenv_scoped_env
	[ "$status" -eq 0 ]
	# Nearest wins: only the single .env from project/envs/default is loaded.
	[ "${lines[0]}" = "LOAD:.env" ]
	[ "${#lines[@]}" -eq 1 ]
}

@test "backward compatibility: no-arg call equals explicit default scope" {
	run dotenv_scoped_env
	[ "$status" -eq 0 ]
	# Pin the absolute expected output, not just equality between two calls.
	[ "${lines[0]}" = "LOAD:.env" ]
	[ "${lines[1]}" = "LOAD:.env.mcp" ]
	[ "${#lines[@]}" -eq 2 ]
	local default_out="$output"

	run dotenv_scoped_env default
	[ "$status" -eq 0 ]
	[ "$output" = "$default_out" ]
}
