#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$ROOT_DIR/bin/rabbit.ci"
FIXTURE="$ROOT_DIR/tests/fixtures/basic"
MOCK_BIN="$ROOT_DIR/tests/fixtures/bin"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expected_version="$(node -p "require('$ROOT_DIR/package.json').version")"
actual_version="$($CLI --version)"
[ "$actual_version" = "$expected_version" ] || fail "CLI version $actual_version did not match package version $expected_version"

cp -R "$FIXTURE/." "$TMP_DIR/repo"
mkdir -p "$TMP_DIR/repo/.rabbit"
printf 'version: legacy\n' > "$TMP_DIR/repo/.rabbit/context.yaml"
git -C "$TMP_DIR/repo" init -q
git -C "$TMP_DIR/repo" checkout -q -b main
git -C "$TMP_DIR/repo" remote add origin git@github.com:example/basic.git

PATH="$MOCK_BIN:$PATH" "$CLI" "$TMP_DIR/repo" >/dev/null
RESOLUTION="$TMP_DIR/repo/.rabbit/repo.yaml"
[ -f "$RESOLUTION" ] || fail "command did not generate .rabbit/repo.yaml"
grep -Fqx "kind: repoResolution" "$RESOLUTION" || fail "resolution kind changed"
grep -Fqx "version: rabbit.ci/repo-resolution/v1" "$RESOLUTION" || fail "resolution version changed"
grep -Fqx "  name: repo" "$RESOLUTION" || fail "resolution did not use repository directory name"
grep -Fqx "  owner: example" "$RESOLUTION" || fail "resolution did not resolve GitHub owner"
grep -Fqx -- "- name: main" "$RESOLUTION" || fail "resolution did not include branch rules"
grep -Fqx -- "- name: production" "$RESOLUTION" || fail "resolution did not include environments"
grep -Fqx "  - DEPLOY_TOKEN" "$RESOLUTION" || fail "resolution did not include environment secret names"
grep -Fqx -- '- path: ".github/workflows/ci.yml"' "$RESOLUTION" || fail "resolution did not include workflows"

PATH="$MOCK_BIN:$PATH" "$CLI" --check "$TMP_DIR/repo" >/dev/null
if "$CLI" --check "$ROOT_DIR/tests/fixtures/invalid" >/dev/null 2>&1; then
  fail "invalid resolution passed validation"
fi
json="$(PATH="$MOCK_BIN:$PATH" "$CLI" --json "$TMP_DIR/repo")"
printf '%s' "$json" | jq -e '.kind == "repoResolution"' >/dev/null || fail "JSON did not identify the resolution kind"
printf '%s' "$json" | jq -e '.branches[0].rules.pull_request.approvals == 1' >/dev/null || fail "JSON did not resolve branch rules"
printf '%s' "$json" | jq -e '.environments[0].secrets == ["DEPLOY_TOKEN"]' >/dev/null || fail "JSON exposed the wrong environment secrets"
printf '%s' "$json" | jq -e '.workflows[0].triggers.push.branches == ["main"]' >/dev/null || fail "JSON did not resolve workflow triggers"

no_origin="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$no_origin"' EXIT
cp -R "$FIXTURE/." "$no_origin/repo"
json="$($CLI --json "$no_origin/repo")"
printf '%s' "$json" | jq -e '.branches == [] and .environments == []' >/dev/null || fail "offline resolution did not keep GitHub lists empty"

printf 'ok - rabbit.ci generation and integration checks\n'
