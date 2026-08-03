# rabbit-repo

`rabbit.ci` is the repository integration layer for Rabbit CI.

Run one command in a repository:

```bash
rabbit.ci
```

It writes `.rabbit/repo.yaml` and reports the read-only integration context:
repository identity, current default branch, GitHub visibility and permissions
available to the current `gh` token, repo-owned signals, and the next missing
pieces worth improving.

The generated file is intentionally small and committed with the code. Dynamic
state stays in command output, so it remains current without leaking secrets or
turning GitHub state into permanent repository truth.

## Status

This is the focused successor to the repository integration work that first
lived in `dev.kit`. `dev.kit` remains responsible for broad generated context;
Rabbit CI execution remains in its integrations and backends.

## Quick start

Install the CLI globally:

```bash
npm install --global @udx/rabbit-repo
```

Then generate, inspect in JSON, or validate the current contract:

```bash
rabbit.ci /path/to/repository
rabbit.ci /path/to/repository --json
rabbit.ci /path/to/repository --check
```

`--json` is the dynamic integration interface. It contains no token or secret
values. A GitHub repository is queried only when an `origin` points to GitHub;
the output distinguishes unavailable tooling, an unauthenticated token,
insufficient access, and a repository that is not visible to the token.

## Contract

The v1 contract is intentionally small:

- `repository.name` identifies the codebase.
- `repository.owner` is included when a GitHub origin supplies one.
- `repository.default_branch` is the best locally or remotely observed default.
- `discovery.read_only: true` guarantees discovery never reads secret values or
  mutates GitHub, workflow, environment, or cloud state.

Read the [repository contract](docs/repo-contract.md),
[repository discovery and initialization](docs/repository-discovery.md), and
[dev.kit migration boundary](docs/dev-kit-migration.md) before extending it.

## Development

```bash
make test
```

## Product context

Rabbit CI helps teams own how software moves—and proves the work as it moves.
Its delivery route is repository-centric, policy-governed, and evidence-producing:
move fast, protect the path, craft proofs.
