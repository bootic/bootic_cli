# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake spec
# or
bundle exec rspec spec/

# Run a single spec file
bundle exec rspec spec/connectivity_spec.rb

# Run the CLI locally (without installing the gem)
bundle exec ruby -Ilib bin/bootic help

# Build and install the gem locally
gem build bootic_cli.gemspec && gem install pkg/bootic_cli-*.gem
```

## Architecture

This is a Ruby CLI gem built on [Thor](https://github.com/rails/thor). The entry point is `bin/bootic` → `lib/bootic_cli/cli.rb`.

### Command structure

- `BooticCli::CLI` (in `cli.rb`) — the top-level Thor class. Handles `setup`, `login`, `logout`, `check`, `runner`, `console`.
- `BooticCli::Command` (in `command.rb`) — base class for subcommand groups. Subclasses call `declare self, 'Description'` to register themselves with `CLI` as a subcommand.
- Built-in subcommands live in `lib/bootic_cli/commands/` (e.g. `themes.rb`, `orders.rb`).
- Custom user commands auto-loaded from `~/bootic/*.rb` (overridable via `BTC_CUSTOM_COMMANDS_PATH` env var).

### Auth / session

`BooticCli::Connectivity` (mixed into every command class) provides `session`, `root`, and `shop` helpers.

- `Session` wraps OAuth2 login and the `bootic_client` gem. Credentials (client_id, client_secret, access_token) are persisted via `Store`.
- `Store` uses Ruby's `PStore` at `~/.bootic/store.pstore`, namespaced by environment (`production` by default, controlled by `ENV` env var).
- All commands that require auth call `logged_in_action { ... }`, which checks both client keys and access token before yielding.

### Theme system

The most complex part of the codebase. Three theme implementations share a common interface (`templates`, `assets`, `add_template`, `remove_template`, `add_asset`, `remove_asset`):

| Class | Location | Description |
|---|---|---|
| `APITheme` | `themes/api_theme.rb` | Wraps a remote Bootic theme resource |
| `FSTheme` | `themes/fs_theme.rb` | Reads/writes from a local directory |
| `MemTheme` | `themes/mem_theme.rb` | In-memory theme, used in tests |

**Diffing:** `ThemeDiff` compares any two theme objects using `UpdatedTheme` (files that exist in both but differ by timestamp/digest) and `MissingItemsTheme` (files present in one side but absent in the other).

**Workflows:** `Themes::Workflows` orchestrates high-level operations (`pull`, `push`, `sync`, `compare`, `publish`, `watch`) using `ThemeDiff`. Asset downloads are parallelised via `WorkerPool`. Network/server errors are retried up to `MAX_ATTEMPTS` (3); if they persist, a `RetryableError` is raised and caught in the command layer with a user-facing message.

**ThemeSelector:** resolves which remote shop and theme to operate on (dev vs. public), and pairs a local directory to a shop subdomain via a `.state` file written into the theme directory.

### Environment support

Set `ENV=staging` (or any value) before running commands to use a separate credential namespace in the PStore, allowing multiple environments to coexist.
