# Rabbit CI repository contract

`rabbit.ci` generates `.rabbit/repo.yaml`, the committed repository entry point
for Rabbit CI integrations.

```yaml
version: rabbit.ci/repo/v1
repository:
  name: 'example-service'
  owner: 'example-org'
  default_branch: 'main'
discovery:
  read_only: true
```

The file contains only portable repository facts. It intentionally excludes
tokens, secrets, open pull requests, workflow runs, and mutable environment
state.

`.rabbit/context.yaml` is a legacy artifact, not a second contract. `rabbit.ci`
does not read it when generating or checking `.rabbit/repo.yaml`. Its dynamic
report sets `context.legacy_context` when the file remains, and recommends the
repository retire it after the committed contract has been reviewed.

`rabbit.ci --json` is the companion dynamic interface. When an `origin` points
to GitHub, it uses the current `gh` token for one read-only repository lookup.
Its status makes the boundary explicit:

- `available`: repository metadata and the token's reported permissions are visible.
- `not_accessible`: the repository is absent or not visible to the token.
- `forbidden`: the token is authenticated but cannot read the repository.
- `unauthenticated`: the `gh` token cannot authenticate the lookup.
- `not_configured` or `unavailable`: no GitHub origin exists, the CLI is absent,
  or a transient lookup failed.

The same output carries `context.signals` and `context.improvements`. Those are
small, observable prompts for the next repo-owned improvement—not automatic
changes and not a policy engine.

For how the contract and dynamic report behave before a repository has an
initial commit, remote, or GitHub connection, read
[repository discovery and initialization](repository-discovery.md).

## Extension rules

- Add explicit, versioned fields only when a Rabbit CI integration consumes them.
- Keep secret values out of the contract and out of command output.
- Keep workflow policy, Rabbit Env configuration, and execution configuration in
  their own contracts until a real integration needs a stable link.
- Keep discovery read-only unless a separately approved command defines a
  write boundary.
