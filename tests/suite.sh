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

[ "$($CLI --version)" = "0.1.1" ] || fail "CLI version did not match package version"

cp -R "$FIXTURE/." "$TMP_DIR/repo"
mkdir -p "$TMP_DIR/repo/.rabbit"
printf 'version: legacy\n' > "$TMP_DIR/repo/.rabbit/context.yaml"
git -C "$TMP_DIR/repo" init -q
git -C "$TMP_DIR/repo" checkout -q -b main
git -C "$TMP_DIR/repo" remote add origin git@github.com:example/basic.git

PATH="$MOCK_BIN:$PATH" "$CLI" "$TMP_DIR/repo" >/dev/null
CONTRACT="$TMP_DIR/repo/.rabbit/repo.yaml"
[ -f "$CONTRACT" ] || fail "command did not generate .rabbit/repo.yaml"
grep -Fqx "version: rabbit.ci/repo/v1" "$CONTRACT" || fail "contract version changed"
grep -Fqx "  name: 'repo'" "$CONTRACT" || fail "contract did not use repository directory name"
grep -Fqx "  owner: 'example'" "$CONTRACT" || fail "contract did not resolve GitHub owner"

PATH="$MOCK_BIN:$PATH" "$CLI" --check "$TMP_DIR/repo" >/dev/null
if "$CLI" --check "$ROOT_DIR/tests/fixtures/invalid" >/dev/null 2>&1; then
  fail "invalid contract passed validation"
fi
json="$(PATH="$MOCK_BIN:$PATH" "$CLI" --json "$TMP_DIR/repo")"
printf '%s\n' "$json" | grep -Fq '"written":true' || fail "JSON report did not record contract write"
printf '%s\n' "$json" | grep -Fq '"status":"available"' || fail "GitHub capability was not reported"
printf '%s\n' "$json" | grep -Fq '"push":true' || fail "GitHub token permission was not reported"
printf '%s\n' "$json" | grep -Fq '"README.md"' || fail "repo context signals were not reported"
printf '%s\n' "$json" | grep -Fq '"legacy_context":true' || fail "legacy context was not reported"
printf '%s\n' "$json" | grep -Fq 'Retire legacy .rabbit/context.yaml' || fail "legacy context migration was not suggested"

no_origin="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$no_origin"' EXIT
cp -R "$FIXTURE/." "$no_origin/repo"
json="$($CLI --json "$no_origin/repo")"
printf '%s\n' "$json" | grep -Fq '"status":"not_configured"' || fail "missing GitHub origin was not explicit"
printf '%s\n' "$json" | grep -Fq '"legacy_context":false' || fail "missing legacy context was not explicit"

printf 'ok - rabbit.ci generation and integration checks\n'
