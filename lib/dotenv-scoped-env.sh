# shellcheck shell=bash
#
# dotenv-scoped-env — a direnv plugin.
#
# direnv auto-sources every *.sh in ~/.config/direnv/lib/ into each .envrc,
# so this file only DEFINES a function; it runs no global code. Use it from a
# project's .envrc like so:
#
#     dotenv_scoped_env            # loads the "default" scope
#     dotenv_scoped_env staging    # loads the "staging" scope
#
# dotenv_scoped_env walks up the directory tree from $PWD looking for the first
# ancestor that contains an `envs/<scope>/` directory, then loads the env files
# listed in `env_files` from it (later files override earlier ones). Missing
# files are silently skipped via direnv's `dotenv_if_exists`.
dotenv_scoped_env() {
	local scope="${1:-default}"

	# Files loaded in order; later files override earlier ones.
	# Extend this list to support more layers (e.g. .env.local).
	local -a env_files=(.env .env.mcp)

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

	if [ -n "$scope_dir" ]; then
		local f
		for f in "${env_files[@]}"; do
			dotenv_if_exists "$scope_dir/$f"
		done
	else
		echo "direnv: envs/$scope not found up the tree" >&2
	fi
}
