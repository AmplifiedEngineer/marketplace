# marketplace

> **Renamed.** The GitHub organization was `pragmatic-engineer`. It is now `amplifiedengineer`. The marketplace name stays `pragmatic-engineer`. The plugin id `playbook@pragmatic-engineer` does not change. If you added the marketplace from the old address, remove it and add it again: run `claude plugin marketplace remove pragmatic-engineer`, then `claude plugin marketplace add amplifiedengineer/marketplace`, then `claude plugin install playbook@pragmatic-engineer` if the plugin is no longer installed. If the retired hooks plugin is still installed, run `claude plugin uninstall playbook-hooks@pragmatic-engineer`.

The `pragmatic-engineer` plugin marketplace for Claude Code. It lists one plugin, `playbook`.

The plugin lives in [amplifiedengineer/playbook](https://github.com/amplifiedengineer/playbook) under `plugins/playbook`, next to the `playbook` binary. This repository holds only the listing and the checks on it.

The listing needs Claude Code 2.1.77 or later, which serves `git-subdir` plugins from a monorepo without cache collisions. With git older than 2.39 (for example Ubuntu 22.04), use Claude Code 2.1.288 or later.

## Install the plugin

```sh
claude plugin marketplace add amplifiedengineer/marketplace
claude plugin install playbook@pragmatic-engineer
```

The plugin works on its own. The `playbook` binary is optional. It adds the hooks and the launcher.

## Install the binary

Homebrew first:

```sh
brew install amplifiedengineer/tap/playbook
playbook setup
```

Homebrew 6.0.0 and later asks you to trust non-official taps. Installing a fully qualified name, as above, trusts only that formula.

The install records that trust, so a later `brew upgrade playbook` works by short name. To install by short name without the full name first, run `brew tap amplifiedengineer/tap`, then `brew trust --formula amplifiedengineer/tap/playbook`. For `pbtop`, trust `amplifiedengineer/tap/pbtop`.

The broader option is `brew trust amplifiedengineer/tap`. It covers every current and future formula in the tap.

Run `brew trust` to list what you trust. Run `brew untrust <target>` to remove an entry, with `--formula` for a formula.

Or use the install script. It checks the SHA256 checksum of the release binary:

```sh
curl -fsSL https://raw.githubusercontent.com/amplifiedengineer/playbook/main/install.sh | bash
playbook setup
```

The full install guide is in the [playbook repository](https://github.com/amplifiedengineer/playbook/blob/main/docs/guides/00-install.md).

## Check the listing

```sh
shell/check-marketplace.sh
```

Set `OFFLINE=1` to skip the lookup of the plugin manifest. For what it checks, how releases move the pin and how to roll back, see [docs/how-the-listing-works.md](docs/how-the-listing-works.md).

## History

The plugin once lived here. Its history stays readable in this repository, up to the release `playbook` 0.27.2.

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
