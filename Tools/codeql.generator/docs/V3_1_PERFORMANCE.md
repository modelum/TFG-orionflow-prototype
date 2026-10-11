# OrionFlow V3.1 performance

Measurements were taken on 2026-10-11 against the same internal fixture
database with CodeQL 2.27.2. Times are wall-clock seconds.

| Activity | JPA | Mongo | Both |
| --- | ---: | ---: | ---: |
| `query compile --check-only` (9 queries) | 114.274 | 110.310 | 104.415 |
| `database analyze` total | 135.864 | 122.954 | 115.534 |
| Slowest individual evaluation | 5.0 | 1.2 | 0.923 |

Database creation took 48.530 seconds. The `database analyze` totals include
query-plan compilation; evaluation timings are reported separately by CodeQL.

The Both Feature Rename query previously exhibited an approximately 52.9
second evaluation on this fixture. Routing each annotation to its selected
adapter before evaluating the adapter-specific predicate reduced its final
evaluation to 0.923 seconds.

CodeQL selected `-Xmx3434M` and `--off-heap-ram=3660` for these runs. The CLI
logs did not expose actual peak resident memory, so no measured peak-memory
claim is made.

