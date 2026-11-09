#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Igor Santos
# SPDX-License-Identifier: Apache-2.0
#
# check-marketplace.test.sh: runs check-marketplace.sh offline against copies of
# the listing with a pin, a bad pin and mismatched versions.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

# The latest release lookup is injected, so the tests never use the network.
latest_tag="v1.2.3"
old_age=7200
new_age=60

# case NAME WANT(pass|fail) JQ_FILTER [LATEST_TAG] [LATEST_AGE_SECONDS]
case_() {
  local name="$1" want="$2" got=pass
  jq "$3" "$ROOT/.claude-plugin/marketplace.json" >"$work/m.json"
  PLAYBOOK_LATEST_TAG="${4:-}" PLAYBOOK_LATEST_AGE_SECONDS="${5:-$old_age}" OFFLINE=1 MARKETPLACE_JSON="$work/m.json" "$ROOT/shell/check-marketplace.sh" >"$work/out" 2>&1 || got=fail
  if [ "$got" = "$want" ]; then
    echo "PASS $name"
  else
    echo "FAIL $name: wanted $want, got $got"
    cat "$work/out"
    failures=$((failures + 1))
  fi
}

pin='(.plugins[] | select(.name == "playbook") | .source.ref)'
case_ "the listing as it is" pass '.'
case_ "a release pin with its version" pass "$pin = \"v1.2.3\" | .metadata.version = \"1.2.3\""
case_ "a pin that is not a release tag" fail "$pin = \"main\" | .metadata.version = \"1.2.3\""
case_ "a pin and a different version" fail "$pin = \"v1.2.3\" | .metadata.version = \"1.2.4\""
case_ "a pin without a version" fail "$pin = \"v1.2.3\""
case_ "a version without a pin" fail '.metadata.version = "1.2.3"'
case_ "a version that is not MAJOR.MINOR.PATCH" fail "$pin = \"v1.2.3\" | .metadata.version = \"1.2\""
case_ "a sha" fail '(.plugins[] | select(.name == "playbook") | .source.sha) = "abc"'
case_ "the old marketplace name" fail '.name = "pragmatic-engineer"'

set_pin() { echo "$pin = \"$1\" | .metadata.version = \"${1#v}\""; }
case_ "a pin on the latest release" pass "$(set_pin v1.2.3)" "$latest_tag"
case_ "a pin newer than the latest release, as a release PR carries" pass "$(set_pin v1.3.0)" "$latest_tag"
case_ "a pin older than the latest release" fail "$(set_pin v1.2.2)" "$latest_tag"
case_ "a pin an older minor than the latest release" fail "$(set_pin v0.9.9)" "$latest_tag"
case_ "a pin older than a release that is minutes old" pass "$(set_pin v1.2.2)" "$latest_tag" "$new_age"
case_ "a pin ten patches ahead compares as a number" pass "$(set_pin v1.2.10)" "$latest_tag"
case_ "a latest tag that is not a release tag" fail "$(set_pin v1.2.3)" "latest"

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
