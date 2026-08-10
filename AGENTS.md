# rabbit-repo

`rabbit.ci` generates the repository-level Rabbit CI resolution.

## Start here

1. Read `README.md`.
2. Read `.rabbit/repo.yaml` for the generated resolution.
3. Read `docs/repo-resolution.md` before changing the resolution or validator.

## Boundaries

- Keep the generated resolution reviewable, versioned, and safe to inspect without credentials.
- GitHub discovery is read-only. Do not add policy, workflow, environment, or secret mutations without an explicit approval boundary.
- Keep broad repo-context generation in `dev.kit`; keep execution backends in Rabbit CI integrations.
- Add a fixture and update `tests/suite.sh` when the resolution changes.

## Verification

Run `make test`.
