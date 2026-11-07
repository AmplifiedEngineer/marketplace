# Contributing

This repository holds the `pragmatic-engineer` marketplace listing. The `playbook` plugin, its docs and its checks live in [amplifiedengineer/playbook](https://github.com/amplifiedengineer/playbook), under `plugins/playbook`. Send plugin changes there.

## Where things go

| You change | Edit |
|---|---|
| The marketplace listing | `.claude-plugin/marketplace.json` |
| The check on the listing | `shell/check-marketplace.sh` |
| A skill, command, agent or output style | `plugins/playbook/` in the playbook repository |

## Checks

```sh
shell/check-marketplace.sh
shell/check-marketplace.test.sh
```

## Pull requests

- Conventional commit titles under 73 characters. The squash commit uses the title.
- Commits are signed and carry a `Signed-off-by` line.
- Keep a pull request under 1000 changed lines.
- Write plain English. No em or en dashes.

## Releases

The playbook release workflow pins the `playbook` entry to each release through a `release/vX.Y.Z` pull request, and the `release` workflow here tags and releases `vX.Y.Z` when it merges. [docs/how-the-listing-works.md](docs/how-the-listing-works.md) explains both. Do not move the `ref` or `metadata.version` by hand, except to roll back a release, and do not add a `sha` or an entry `version`. The app key behind `BOT_APP_CLIENT_ID` and `BOT_APP_PRIVATE_KEY` is an organization secret, and an organization admin rotates it.
