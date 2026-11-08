# How the listing works

## The entry

The `playbook` entry in `.claude-plugin/marketplace.json` is a `git-subdir` source:

- `url`: `https://github.com/amplifiedengineer/playbook.git`
- `path`: `plugins/playbook`
- `ref`: a playbook release tag `vX.Y.Z`
- `metadata.version`: the same version, without the `v`

The binary and the plugin share one version line. A pinned plugin always matches a released binary.

## Releases move the pin

1. The playbook release workflow publishes and verifies `vX.Y.Z`.
2. It opens a `release/vX.Y.Z` pull request here from the `igorjs[bot]` app and turns on auto-merge.
3. When the pull request merges, the `release` workflow here tags the merge commit `vX.Y.Z`.
4. It publishes a release with the notes `playbook vA -> vB`.

The `release` workflow acts only on a merged pull request that meets all of these:

- It comes from the app, on a `release/v*` branch of this repository.
- It changes only `.claude-plugin/marketplace.json`.
- It changes only the `playbook` `ref` and `metadata.version`.
- The `ref` matches the branch name.
- The merge commit is on `main`.

The workflow mints an app token from the organization secrets `BOT_APP_CLIENT_ID` and `BOT_APP_PRIVATE_KEY`. The tag ruleset lets only the app create `v` tags. Without those secrets the workflow stops with a notice. The playbook release workflow then tags and releases through the API.

## Roll back

1. Open a pull request that sets `ref` to the previous release tag `vA.B.C`.
2. Set `metadata.version` to `A.B.C` in the same pull request.
3. Run `shell/check-marketplace.sh` before you push.

The tag and release of the bad version stay as they are.

## The check script

`shell/check-marketplace.sh` checks that:

- The marketplace name is `amplifiedengineer`.
- Every source is a `git-subdir` source over https from github.com, with a safe relative path.
- No source sets `sha`, and no entry sets `version`.
- A `ref`, when set, is a release tag `vX.Y.Z`.
- The manifest at that path, at the `ref` or else on the default branch, has the same plugin name.
- With a `ref`, the manifest carries the tag's version.
- `metadata.version`, when set, is `MAJOR.MINOR.PATCH` and matches the `playbook` `ref`.

It looks the manifest up with `gh`. Set `OFFLINE=1` to skip the lookup.

`shell/check-marketplace.test.sh` tests the script. CI also runs `shellcheck`.
