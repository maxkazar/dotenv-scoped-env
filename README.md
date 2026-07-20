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
plugin mechanism. Installing this plugin therefore just means symlinking our
library file into that directory — after which `dotenv_scoped_env` is available
in every `.envrc` on your machine.

When called, `dotenv_scoped_env`:

1. Takes a `scope` argument (default: `default`).
2. Walks up from the current directory to find the **nearest ancestor** that
   contains an `envs/<scope>/` directory.
3. Loads these files from it, in order (later files override earlier ones):
   `.env`, then `.env.mcp` — each via direnv's `dotenv_if_exists`, so a missing
   file is simply skipped.
4. If no `envs/<scope>/` is found anywhere up the tree, prints a warning to
   stderr and returns without error.

## Requirements

- [direnv](https://direnv.net/) >= 2.x
- `bash` (the library uses bash arrays)
- macOS or Linux

## Installation

```bash
git clone https://github.com/<your-user>/dotenv-scoped-env.git
cd dotenv-scoped-env
./install.sh
```

`install.sh` is idempotent — it symlinks `lib/dotenv-scoped-env.sh` into
`${XDG_CONFIG_HOME:-$HOME/.config}/direnv/lib/`, creating the directory if
needed.

### Updating

Pull the latest changes; the symlink already points at the repo, so no
reinstall is required:

```bash
cd dotenv-scoped-env
git pull
```

## Usage

In any project's `.envrc`:

```bash
dotenv_scoped_env default
```

or simply `dotenv_scoped_env` (the scope defaults to `default`). Then run
`direnv allow` once, as usual.

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

The set of files to load lives in a local array inside the function:

```bash
local -a env_files=(.env .env.mcp)
```

Add entries (e.g. `.env.local`) to load more layers. Later entries win.

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
