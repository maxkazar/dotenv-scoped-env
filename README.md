# dotenv-scoped-env

A tiny [direnv](https://direnv.net/) plugin that loads environment files from a
**scoped, shared** location discovered by walking up the directory tree — so
many projects (or many subdirectories of one repo) can share a single set of
`.env` files instead of each keeping its own copy.

It exposes one reusable shell function, `dotenv_scoped_env`, that you call from
any project's `.envrc`.

## How it works

direnv automatically sources every `*.sh` file in
`~/.config/direnv/lib/` into every `.envrc` it evaluates. That is direnv's
plugin mechanism. Installing this plugin therefore just means putting our
library file into that directory — a copy by default, or a symlink with
`--link` — after which `dotenv_scoped_env` is available in every `.envrc` on
your machine.

Its signature is:

```bash
dotenv_scoped_env [scope] [file...]
```

When called, `dotenv_scoped_env`:

1. Takes a `scope` as its first argument (default: `default`).
2. Takes an optional list of files as the remaining arguments (default:
   `.env`, then `.env.mcp`).
3. Walks up from the current directory to find the **nearest ancestor** that
   contains an `envs/<scope>/` directory.
4. Loads the requested files from it, in order (later files override earlier
   ones) — each via direnv's `dotenv_if_exists`, so a missing file is simply
   skipped.
5. If no `envs/<scope>/` is found anywhere up the tree, prints a warning to
   stderr and returns without error.

## Requirements

- [direnv](https://direnv.net/) >= 2.21 (for `dotenv_if_exists`)
- `bash` (the library uses bash arrays)
- macOS or Linux

## Installation

One line — no clone required. It copies the single plugin file into
`${XDG_CONFIG_HOME:-$HOME/.config}/direnv/lib/`, creating the directory if
needed:

```bash
curl -fsSL https://raw.githubusercontent.com/maxkazar/dotenv-scoped-env/main/install.sh | bash
```

`install.sh` is idempotent, so running it again just refreshes the installed
copy — that is also how you **update** (re-run the same one-liner). After that
the repository is not needed; the plugin is a self-contained copy.

### For contributors

Work from a checkout and install with `--link` instead, so the plugin in
direnv's lib dir is a **symlink** back to the repo:

```bash
git clone https://github.com/maxkazar/dotenv-scoped-env.git
cd dotenv-scoped-env
./install.sh --link
```

With `--link`, `git pull` updates the plugin in place — the symlink already
points at the repo, so no reinstall is required.

### Updating

- **Installed via the one-liner (copy):** re-run the one-liner, or from a
  checkout run `./install.sh --update`.
- **Installed with `--link`:** just `git pull` in the checkout.

## Usage

In any project's `.envrc`:

```bash
dotenv_scoped_env default
```

or simply `dotenv_scoped_env` (the scope defaults to `default`). Then run
`direnv allow` once, as usual.

#### Choosing which files to load

Pass the files you want after the scope. They load in order, so later files
override earlier ones:

```bash
dotenv_scoped_env default .env .env.mcp        # the default set, made explicit
dotenv_scoped_env default .env .env.local      # skip .env.mcp, add .env.local
dotenv_scoped_env staging .env                 # a single file from envs/staging
```

With no file arguments, the default list `.env .env.mcp` is used.

### Example tree

```
my-workspace/
├── envs/
│   ├── default/
│   │   ├── .env          # shared vars for every project below
│   │   └── .env.mcp      # overrides / MCP-specific vars
│   └── staging/
│       └── .env
├── service-a/
│   └── .envrc            # dotenv_scoped_env          -> loads envs/default
└── service-b/
    └── .envrc            # dotenv_scoped_env staging   -> loads envs/staging
```

Both `service-a` and `service-b` live below `my-workspace/envs/`, so
`dotenv_scoped_env` finds it by walking up the tree — no per-project `.env`
copies needed.

## Extending the file list

Pass the files as arguments after the scope — no need to edit the plugin:

```bash
dotenv_scoped_env default .env .env.mcp .env.local
```

Later entries win. If you omit the file arguments entirely, the built-in default
list `.env .env.mcp` is used.

## Development

The plugin is pure bash and is checked with [shellcheck](https://www.shellcheck.net/)
and tested with [bats](https://github.com/bats-core/bats-core):

```bash
shellcheck lib/dotenv-scoped-env.sh install.sh
bats test/
```

Both run automatically on every push and pull request via GitHub Actions
(see `.github/workflows/ci.yml`).

## Backward compatibility

The public function name `dotenv_scoped_env` is a stable contract. Any
behavioral change that would break existing `.envrc` callers will ship under a
new, versioned name (e.g. `dotenv_scoped_env_v2`) rather than mutating this one.

## A note on secrets

This repository ships **no** `.env` files. Your `.env` and `.env.mcp` files are
your own — keep them out of version control. Nothing here is committed on your
behalf.

## License

Released under the [MIT License](LICENSE).
