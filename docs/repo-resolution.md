# Rabbit CI repository resolution

`rabbit.ci` generates `.rabbit/repo.yaml`, a committed resolution of the
repository's GitHub delivery shape.

```yaml
kind: repo
version: udx.dev/rabbit.ci/repo/v1
repository:
  name: 'example-service'
  owner: 'example-org'
  default_branch: 'main'
branches: []
environments: []
workflows: []
```

The file contains branch rules, GitHub Environment configuration, and workflow
triggers. It excludes tokens, secret values, variable values, pull requests,
and workflow runs.

`.rabbit/context.yaml` is legacy. `rabbit.ci` does not read, rewrite, or delete
it.

`rabbit.ci --json` and `rabbit.ci --yaml` emit the same data without writing a
file. When an `origin` points to GitHub, the command uses the current `gh`
token for read-only discovery.

For how the resolution behaves before a repository has an
initial commit, remote, or GitHub connection, read
[repository discovery and initialization](repository-discovery.md).

## Extension rules

- Add a field only when an integration can consume it.
- Keep secret and variable values out of the resolution and command output.
- Keep execution configuration outside this file.
- Keep discovery read-only unless a separately approved command defines a
  write boundary.
