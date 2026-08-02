# rabbit-repo

`rabbit.ci` generates the repository-level Rabbit CI contract and its read-only integration report.

## Start here

1. Read `README.md`.
2. Read `.rabbit/repo.yaml` for the generated contract.
3. Read `docs/repo-contract.md` before changing the contract or validator.

## Boundaries

- Keep the generated contract reviewable, versioned, and safe to inspect without credentials.
- GitHub discovery is read-only. Do not add policy, workflow, environment, or secret mutations without an explicit approval boundary.
- Keep broad repo-context generation in `dev.kit`; keep execution backends in Rabbit CI integrations.
- Add a fixture and update `tests/suite.sh` when the contract changes.

## Verification

Run `make test`.
