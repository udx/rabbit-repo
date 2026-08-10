# rabbit-repo

`rabbit.ci` resolves the GitHub delivery shape of a repository for Rabbit CI.

Run one command in a repository:

```bash
rabbit.ci
```

It writes `.rabbit/repo.yaml` with repository identity, branch rules,
environments, and workflow triggers.

The generated file is committed with the code. Refresh it when GitHub delivery
configuration changes.

`.rabbit/context.yaml` is legacy and is not read by `rabbit.ci`.

## Status

This is the focused successor to the repository integration work that first
lived in `dev.kit`. `dev.kit` remains responsible for broad generated context;
Rabbit CI execution remains in its integrations and backends.

## Quick start

Install the CLI globally:

```bash
npm install --global @udx/rabbit-repo
```

Run the command from the repository you want to resolve:

```bash
rabbit.ci
rabbit.ci --json
rabbit.ci --yaml
```

The default command writes `.rabbit/repo.yaml` and prints a short summary.
`--json` and `--yaml` print the same resolution without writing a file. GitHub
discovery is read-only and unavailable GitHub data is left empty. Secret and
variable values are never written; only their names are included.

## Resolution

The resolution contains executable repository facts:

- branch names and effective GitHub rules;
- environments, deployment branch policies, approvals, and effective secret/variable names;
- workflow paths, triggers, and workflow-level permissions.

Read the [repository resolution](docs/repo-resolution.md),
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
