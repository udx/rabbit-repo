# Repository discovery and initialization

`rabbit.ci` creates one repository-owned artifact:

```text
.rabbit/repo.yaml
```

Everything else it discovers is read-only. The command reports repository
identity, locally observed context, and GitHub capability only when the current
`gh` token can verify it. It does not create commits, configure remotes, change
GitHub settings, run workflows, or read secret values.

## What the output means

The generated resolution contains portable facts that belong with the
repository: branch rules, environments, and workflow triggers. It never stores
credentials, secret values, variable values, or workflow-run state.

Secret and variable names are resolved from organization, repository, and
environment scopes without reading their values. Only configured GitHub
Environments appear in `environments`.

If `.rabbit/context.yaml` is present, the command does not inspect, rewrite, or
delete it; completing the migration remains a repository-owned reviewed change.

The resolution reports only what it observes. For GitHub, that means:

- no GitHub origin leaves scoped GitHub configuration empty;
- no usable `gh` client or repository visibility leaves GitHub-discovered
  configuration empty;
- a visible repository supplies its branches, rules, and environments.

## New or local repositories

A repository may legitimately have no initial commit, remote, or GitHub
connection. In that state, `rabbit.ci` still writes and validates
`.rabbit/repo.yaml`, but it does not try to initialize git history or choose a
hosting destination. Creating the first commit, adding an `origin`, and
publishing a repository are separate, intentional actions.

This makes local evaluation safe and gives the repository owner a clear path to
improve the missing parts when they are ready.

## Downstream use

Rabbit CI integrations, Worker, GitHub automation, and AI assistants can
consume the same resolution.

For field definitions, read the [repository resolution](repo-resolution.md). For
the boundary with broad repo-context generation, read the
[dev.kit migration note](dev-kit-migration.md).
