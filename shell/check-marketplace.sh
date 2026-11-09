#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Igor Santos
# SPDX-License-Identifier: Apache-2.0
#
# check-marketplace.sh: check the marketplace listing.
# Every plugin source must be a git-subdir source over https, so installs need
# no SSH key. Its ref, when set, is a release tag vX.Y.Z, which the playbook
# release workflow sets. It sets no sha and no version. The path is relative,
# and the manifest there, at the ref or on the default branch, carries the same
# plugin name, and the tag's version when a ref is set. metadata.version is
# MAJOR.MINOR.PATCH, and it and the playbook ref are set together and match.
# A plugin that installs from the playbook repository must pin the latest
# playbook release or a newer tag, which a release PR carries. It may pin the
# previous release for GRACE_SECONDS after the latest one, while the release
# workflow opens the pin PR. Set OFFLINE=1 to skip the lookups.
# MARKETPLACE_JSON checks another file. PLAYBOOK_LATEST_TAG and
# PLAYBOOK_LATEST_AGE_SECONDS replace the release lookup, which the tests use.
set -u
PLAYBOOK_REPO="amplifiedengineer/playbook"
GRACE_SECONDS=3600
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MKT="${MARKETPLACE_JSON:-$ROOT/.claude-plugin/marketplace.json}"
fail=0
bad() { echo "FAIL $*"; fail=1; }
# check_latest_pin NAME REF: fail when REF is older than the latest release.
check_latest_pin() {
  local name="$1" ref="$2" latest="${PLAYBOOK_LATEST_TAG:-}" age="${PLAYBOOK_LATEST_AGE_SECONDS:-}"
  if [ -z "$latest" ]; then
    [ "${OFFLINE:-0}" = 1 ] && return
    local release published
    if ! release=$(gh api "repos/$PLAYBOOK_REPO/releases/latest" --jq '.tag_name + " " + .published_at' 2>&1); then
      bad "$name cannot look up the latest $PLAYBOOK_REPO release: $release"; return
    fi
    latest="${release% *}"
    published="${release#* }"
    age=$(( $(date +%s) - $(date -d "$published" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$published" +%s) ))
  fi
  if ! [[ "$latest" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    bad "$name latest release tag is not vX.Y.Z (got $latest)"; return
  fi
  if [ "$ref" = "$latest" ] || [ "$(printf '%s\n%s\n' "$ref" "$latest" | sort -V | tail -n 1)" = "$ref" ]; then
    echo "PASS $name pin $ref is the latest release $latest or newer"
  elif [ "${age:-$GRACE_SECONDS}" -lt "$GRACE_SECONDS" ]; then
    echo "PASS $name pin $ref is behind $latest, which is under $GRACE_SECONDS s old; the release workflow is moving it"
  else
    bad "the $name pin is $ref, the latest $PLAYBOOK_REPO release is $latest; the release workflow moves it, or run: gh workflow run release.yml -R $PLAYBOOK_REPO -f version=${latest#v}"
  fi
}
jq empty "$MKT" 2>/dev/null || { echo "FAIL: marketplace.json is not valid JSON"; exit 1; }
if [ "$(jq -r '.name' "$MKT")" = "amplifiedengineer" ]; then
  echo "PASS name is amplifiedengineer"
else
  bad "name must be amplifiedengineer"
fi
mversion=$(jq -r '.metadata.version // empty' "$MKT")
if [ -n "$mversion" ] && ! [[ "$mversion" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  bad "metadata.version must be MAJOR.MINOR.PATCH (got $mversion)"
fi
n=$(jq '.plugins | length' "$MKT")
[ "$n" -ge 1 ] || bad "the marketplace lists no plugin"
i=0
while [ "$i" -lt "$n" ]; do
  p=".plugins[$i]"
  name=$(jq -r "$p.name" "$MKT")
  i=$((i + 1))
  stype=$(jq -r "$p.source.source // empty" "$MKT")
  url=$(jq -r "$p.source.url // empty" "$MKT")
  path=$(jq -r "$p.source.path // empty" "$MKT")
  if [ "$stype" != "git-subdir" ]; then
    bad "$name source must be git-subdir (got ${stype:-none})"; continue
  fi
  if [[ "$url" == *"/./"* || "$url" == *"/../"* ]] || ! [[ "$url" =~ ^https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)\.git$ ]]; then
    bad "$name url must be an https github .git url (got $url)"; continue
  fi
  repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  if ! [[ "$path" =~ ^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$ ]] || [[ "/$path/" == *"/../"* ]]; then
    bad "$name path must be a relative path without .. (got ${path:-none})"; continue
  fi
  if [ "$(jq "$p.source | has(\"sha\")" "$MKT")" = true ] ||
     [ "$(jq "$p | has(\"version\")" "$MKT")" = true ]; then
    bad "$name must not set sha or version"; continue
  fi
  ref=$(jq -r "$p.source.ref // empty" "$MKT")
  if [ "$(jq "$p.source | has(\"ref\")" "$MKT")" = true ] &&
     ! [[ "$ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    bad "$name ref must be a release tag vX.Y.Z (got ${ref:-none})"; continue
  fi
  if [ "$name" = playbook ] && { [ -n "$ref" ] || [ -n "$mversion" ]; } && [ "$ref" != "v$mversion" ]; then
    bad "the playbook ref (${ref:-none}) and metadata.version (${mversion:-none}) must be set together and match"
  fi
  echo "PASS $name source is git-subdir over https: $repo $path${ref:+ at $ref}"
  if [ "$repo" = "$PLAYBOOK_REPO" ] && [ -n "$ref" ]; then
    check_latest_pin "$name" "$ref"
  fi
  [ "${OFFLINE:-0}" = 1 ] && continue
  if ! command -v gh >/dev/null 2>&1; then
    bad "$name cannot be looked up: gh is not installed (set OFFLINE=1 to skip)"; continue
  fi
  errf=$(mktemp)
  manifest=$(gh api -H "Accept: application/vnd.github.raw" \
    "repos/$repo/contents/$path/.claude-plugin/plugin.json${ref:+?ref=$ref}" 2>"$errf")
  found=$(jq -r '.name // empty' <<<"$manifest" 2>/dev/null)
  err=$(tr '\n' ' ' <"$errf")
  rm -f "$errf"
  if [ "$found" != "$name" ]; then
    bad "$name does not resolve: $repo/$path/.claude-plugin/plugin.json${ref:+ at $ref} has name '${found:-none}' ${err:+(gh said: $err)}"
    continue
  fi
  echo "PASS $name resolves: $repo/$path${ref:+ at $ref} has a manifest with this name"
  if [ -n "$ref" ]; then
    pversion=$(jq -r '.version // empty' <<<"$manifest" 2>/dev/null)
    if [ "v$pversion" = "$ref" ]; then
      echo "PASS $name at $ref carries version $pversion"
    else
      bad "$name at $ref carries version '${pversion:-none}', not ${ref#v}"
    fi
  fi
done
exit "$fail"
