# shellcheck shell=bash
#
# dotenv-scoped-env — a direnv plugin.
#
# direnv auto-sources every *.sh in ~/.config/direnv/lib/ into each .envrc,
# so this file only DEFINES a function; it runs no global code. Use it from a
# project's .envrc like so:
#
#     dotenv_scoped_env                       # scope "default", file .env
#     dotenv_scoped_env staging               # scope "staging", file .env
#     dotenv_scoped_env default .env .env.local   # scope "default", explicit file list
#
# Signature:
#
#     dotenv_scoped_env [scope] [file...]
#
#   - scope    first positional arg (default: "default"); names the envs/<scope>/
#              directory to look for.
#   - file...  remaining positional args; the env files to load, in order (later
#              files override earlier ones). When omitted, defaults to a single
#              ".env".
#
# dotenv_scoped_env walks up the directory tree from $PWD looking for the first
# ancestor that contains an `envs/<scope>/` directory, then loads the requested
# files from it. Missing files are silently skipped via direnv's
# `dotenv_if_exists`. If no matching scope directory is found, it warns on stderr
# and returns without error.
dotenv_scoped_env() {
	local scope="${1:-default}"
	# Drop the scope arg (if any); whatever remains is the explicit file list.
	[ "$#" -gt 0 ] && shift

	# Files loaded in order; later files override earlier ones. Callers may pass
	# their own list; otherwise fall back to the default single ".env".
	local -a env_files
	if [ "$#" -gt 0 ]; then
		env_files=("$@")
	else
		env_files=(.env)
	fi

	# Walk up the tree to find the nearest ancestor holding envs/$scope.
	local scope_dir="" dir="$PWD"
	while true; do
		if [ -d "$dir/envs/$scope" ]; then
			scope_dir="$dir/envs/$scope"
			break
		fi
		[ "$dir" = "/" ] && break
		dir="$(dirname "$dir")"
	done

	if [ -z "$scope_dir" ]; then
		echo "direnv: envs/$scope not found up the tree" >&2
		return 0
	fi

	local f
	for f in "${env_files[@]}"; do
		dotenv_if_exists "$scope_dir/$f"
	done
}
