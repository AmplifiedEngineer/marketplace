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

# case NAME WANT(pass|fail) JQ_FILTER
case_() {
  local name="$1" want="$2" got=pass
  jq "$3" "$ROOT/.claude-plugin/marketplace.json" >"$work/m.json"
  OFFLINE=1 MARKETPLACE_JSON="$work/m.json" "$ROOT/shell/check-marketplace.sh" >"$work/out" 2>&1 || got=fail
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

if [ "$failures" -ne 0 ]; then
  echo "$failures failed"
  exit 1
fi
echo "all passed"
