# OrionFlow V3.2 performance

The recorded run used the same fixture database and CodeQL 2.27.2 for every
profile. Compilation and evaluation were kept distinguishable in the CodeQL
logs.

| Measurement | JPA | MongoDB | both |
|---|---:|---:|---:|
| Queries | 16 | 16 | 16 |
| `database analyze` total | 218.45 s | 218.64 s | 217.59 s |
| Maximum individual evaluation | 6.0 s | 2.7 s | 2.4 s |

Most of the total was query-plan compilation. Evaluation remained bounded on
the fixture: Call Graph queries completed in roughly three seconds or less in
the recorded JPA run, while Cast Attribute was the slowest at six seconds.

The design controls cost in two places:

- Call Graph follows only one or two resolved call edges and never computes an
  unrestricted transitive closure.
- Global DataFlow is generated only for CAST operations and starts from one
  literal-bound field rather than all fields in the database.

These are local observations, not guarantees for larger applications. Future
benchmarks should report database creation, plan compilation, evaluation, peak
memory, and result-set equivalence separately.

