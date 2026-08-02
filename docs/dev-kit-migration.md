# From dev.kit to rabbit.ci

`dev.kit` established an important pattern: inspect repo-owned evidence,
preserve unresolved gaps, and generate context without guessing. Its
`.rabbit/context.yaml` remains a generated summary of a repository's current
state.

`rabbit.ci` extracts the narrower repository integration concern:

| Concern | Owner |
| --- | --- |
| Detect docs, manifests, commands, dependencies, and gaps | `dev.kit` |
| Generate repository identity and report a safe discovery boundary | `rabbit.ci` |
| Resolve lifecycle policy and environment routing | Rabbit CI policy and Rabbit Env |
| Execute declared work | Worker and backend integrations |
| Collaboration, reviews, checks, and automation | GitHub |

`rabbit.ci` generates the compact `.rabbit/repo.yaml` contract. A future adapter
may let `dev.kit` surface it in generated context, but neither tool should take
over the other's job.
