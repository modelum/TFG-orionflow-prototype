# OrionFlow V3.2 test results

Validation date: 2026-10-11.

## Toolchain

- Generator build: Maven with JDK 11 and Xtend 2.25.0.
- CodeQL CLI: 2.27.2.
- CodeQL Java pack: `codeql/java-all@9.3.2`.
- CodeQL DataFlow pack: `codeql/dataflow@2.1.15`.
- Dataset: checked-in internal Java fixtures.

## Maven and generation

- Unit/integration tests: 35 passed, 0 failures, 0 errors, 0 skipped.
- Clean Maven test time: 13.38 s in the recorded local run.
- Profiles generated: default, JPA, MongoDB, and both.
- Operation queries: 16 per profile.
- Default and explicit JPA generation: byte-equivalent.
- Modules include `orion_callgraph.qll`; global-flow configuration appears only
  inside Cast Attribute and Cast Reference queries.

## CodeQL compatibility and execution

- Five directly affected queries were compiled first: 5/5 passed.
- Full `query compile --check-only`: 48/48 passed across JPA, MongoDB, and both.
- Fixture database creation: passed.
- `database analyze`: all three 16-query profiles passed.
- Total analyze time, including plan compilation: JPA 218.45 s, MongoDB
  218.64 s, both 217.59 s.
- Slowest observed query evaluation: 6.0 s (JPA Cast Attribute).

## SARIF oracle

| Profile | Raw results | Unique results |
|---|---:|---:|
| JPA | 175 | 169 |
| MongoDB | 55 | 55 |
| both | 230 | 224 |

The normalized `both` set is exactly `set(JPA) union set(MongoDB)`: 224
expected, 224 obtained, 0 missing, 0 extra.

V3.2-specific results in `both`:

- Call Graph: 24 findings.
- Global CAST DataFlow: 7 findings (3 Cast Attribute, 4 Cast Reference).
- Global DataFlow findings from non-CAST rules: 0.

`scripts/verify-v3_2-results.ps1` also checks the expected one/two-level
positive paths and the following negatives:

- discarded pure return values;
- unrelated overloads;
- unrelated DataFlow sources;
- consumers compatible with the replacement type;
- profile composition outside the exact JPA/MongoDB union.

These numbers validate the internal fixtures. They are not precision, recall,
or F1 measurements against an external ground truth.

