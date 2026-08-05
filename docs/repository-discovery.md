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

The generated contract contains portable facts that belong with the repository.
The command output carries changing context such as available files, suggested
improvements, GitHub visibility, and the token's reported repository
permissions. Keeping these separate makes the committed contract reviewable and
keeps live state current without storing credentials or stale collaboration data.

If `.rabbit/context.yaml` is present, the output marks it as legacy. The command
does not inspect, rewrite, or delete that file; completing the migration remains
a repository-owned reviewed change.

The output reports only what it observes. For GitHub, that means:

- no origin: GitHub is `not_configured`;
- no usable `gh` client or authentication: GitHub is unavailable or
  unauthenticated;
- a token without repository visibility: GitHub is `not_accessible` or
  `forbidden`;
- a visible repository: the report includes its returned permissions.

These are repository signals, not failures. They tell a person or integration
what is available now and what needs an explicit next decision.

## New or local repositories

A repository may legitimately have no initial commit, remote, or GitHub
connection. In that state, `rabbit.ci` still writes and validates
`.rabbit/repo.yaml`, but it does not try to initialize git history or choose a
hosting destination. Creating the first commit, adding an `origin`, and
publishing a repository are separate, intentional actions.

This makes local evaluation safe and gives the repository owner a clear path to
improve the missing parts when they are ready.

## Downstream use

Rabbit CI integrations, Worker, GitHub automation, AI assistants, and future
compliance tooling can consume the same contract and dynamic report. The
contract describes the repository; the dynamic report says what can be
integrated at the time it runs.

For field definitions, read the [repository contract](repo-contract.md). For
the boundary with broad repo-context generation, read the
[dev.kit migration note](dev-kit-migration.md).
