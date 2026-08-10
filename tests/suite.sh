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

if grep -Eq '\<(ruby|jq)\>' "$CLI" "$ROOT_DIR/bin/rabbit.ci.js"; then
  fail "CLI must not require Ruby or jq"
fi

cp -R "$FIXTURE/." "$TMP_DIR/repo"
mkdir -p "$TMP_DIR/repo/.rabbit"
printf 'version: legacy\n' > "$TMP_DIR/repo/.rabbit/context.yaml"
git -C "$TMP_DIR/repo" init -q
git -C "$TMP_DIR/repo" checkout -q -b main
git -C "$TMP_DIR/repo" remote add origin git@github.com:example/basic.git

(
  cd "$TMP_DIR/repo"
  PATH="$MOCK_BIN:$PATH" "$CLI" >/dev/null
)
RESOLUTION="$TMP_DIR/repo/.rabbit/repo.yaml"
[ -f "$RESOLUTION" ] || fail "command did not generate .rabbit/repo.yaml"
node - "$RESOLUTION" <<'NODE' || fail "written YAML did not contain the expected resolution"
const fs = require('node:fs');
const YAML = require('yaml');
const resolution = YAML.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (resolution.kind !== 'repo' || resolution.version !== 'udx.dev/rabbit.ci/repo/v1') process.exit(1);
if (resolution.repository.name !== 'repo' || resolution.repository.owner !== 'example') process.exit(1);
if (resolution.branches[0].rules.pull_request.approvals !== 1) process.exit(1);
if (resolution.configuration.secrets.organization.join(',') !== 'ORG_SECRET') process.exit(1);
if (resolution.configuration.secrets.repository.join(',') !== 'REPO_SECRET') process.exit(1);
if (resolution.configuration.variables.organization.join(',') !== 'ORG_REGION') process.exit(1);
if (resolution.configuration.variables.repository.join(',') !== 'REPO_REGION') process.exit(1);
if (resolution.environments[0].name !== 'production') process.exit(1);
if (resolution.environments[0].secrets.join(',') !== 'DEPLOY_TOKEN') process.exit(1);
if (resolution.environments[0].variables.join(',') !== 'DEPLOY_REGION') process.exit(1);
if (resolution.workflows[0].path !== '.github/workflows/ci.yml') process.exit(1);
NODE

json="$(cd "$TMP_DIR/repo" && PATH="$MOCK_BIN:$PATH" "$CLI" --json)"
yaml="$(cd "$TMP_DIR/repo" && PATH="$MOCK_BIN:$PATH" "$CLI" --yaml)"
node - "$json" "$yaml" <<'NODE' || fail "JSON and YAML output did not match"
const YAML = require('yaml');
const json = JSON.parse(process.argv[2]);
const yaml = YAML.parse(process.argv[3]);
if (JSON.stringify(json) !== JSON.stringify(yaml)) process.exit(1);
NODE

mkdir -p "$TMP_DIR/repo/nested/directory"
(cd "$TMP_DIR/repo/nested/directory" && PATH="$MOCK_BIN:$PATH" "$CLI" --json >/dev/null)

no_environments="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$no_environments"' EXIT
cp -R "$FIXTURE/." "$no_environments/repo"
git -C "$no_environments/repo" init -q
git -C "$no_environments/repo" checkout -q -b main
git -C "$no_environments/repo" remote add origin git@github.com:example/no-environments.git
json="$(cd "$no_environments/repo" && RABBIT_TEST_EMPTY_ENVIRONMENTS=1 PATH="$MOCK_BIN:$PATH" "$CLI" --json)"
node - "$json" <<'NODE' || fail "empty environment configuration did not keep inherited names separate"
const resolution = JSON.parse(process.argv[2]);
if (resolution.environments.length !== 0) process.exit(1);
if (resolution.configuration.secrets.organization.join(',') !== 'ORG_SECRET') process.exit(1);
if (resolution.configuration.secrets.repository.join(',') !== 'REPO_SECRET') process.exit(1);
NODE

no_origin="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$no_environments" "$no_origin"' EXIT
cp -R "$FIXTURE/." "$no_origin/repo"
git -C "$no_origin/repo" init -q
git -C "$no_origin/repo" checkout -q -b main
json="$(cd "$no_origin/repo" && "$CLI" --json)"
yaml="$(cd "$no_origin/repo" && "$CLI" --yaml)"
node - "$json" <<'NODE' || fail "offline resolution did not keep GitHub lists empty"
const resolution = JSON.parse(process.argv[2]);
if (resolution.environments.length !== 0) process.exit(1);
if (resolution.configuration.secrets.organization.length !== 0 || resolution.configuration.variables.repository.length !== 0) process.exit(1);
if (resolution.repository.owner !== undefined) process.exit(1);
NODE
[ ! -e "$no_origin/repo/.rabbit/repo.yaml" ] || fail "output modes wrote a resolution file"
[ -n "$yaml" ] || fail "YAML output was empty"

if (cd "$TMP_DIR/repo" && "$CLI" --check >/dev/null 2>&1); then
  fail "unsupported command succeeded"
fi

printf 'ok - rabbit.ci resolution output checks\n'
