# OrionFlow V2 performance report

## Scope and environment

Measurements in this document were taken on 2026-10-09 on the local Windows
workspace with JDK 11 and Maven 3.9.9. The measured input was
`model/Prueba.orion`, which produces 11 operation queries plus `utils.qll`, the
suite, and pack metadata (14 files total).

No `codeql` executable, CodeQL database, or raw SARIF result was available.
Consequently, database build, QL compilation, QL evaluation, workflow time,
and alert counts are explicitly not reported as V2 measurements. Generator
time is not used as a proxy for any of them.

## Reproducible local measurements

| Activity | Result | What it establishes |
|---|---:|---|
| `mvn clean test` | 11.223 s Maven time | Xtend/Java compilation and 13 tests |
| Runner build/test stage | 12.451 s wall | Same clean test stage measured externally |
| Runner package stage | 13.415 s wall | Shaded generator JAR after the test stage |
| Fixture `mvn clean test` | 3.226 s wall | Eight Java/JPA/Spring fixture sources compile |
| Generate `STRUCTURAL` | 1.270 s | 10 fixture query/metadata files |
| Generate `STRUCTURAL_SEMANTIC` | 1.355 s | 10 fixture query/metadata files |
| Generate `DATAFLOW` | 1.368 s | 10 fixture query/metadata files |

The final runner measurements use `codeql-fixtures.orion`; an earlier smoke run
of `model/Prueba.orion` produced its 14 files in 1.341--1.418 s. These are
single runs and should not be treated as a statistically stable benchmark. They
show that mode selection does not add material generator overhead; the
important unknown remains CodeQL evaluation.

The shaded build reports pre-existing overlapping EMF resources/classes and
the Java 11 run reports Guice illegal reflective access. Neither warning
prevented the build or generation, but dependency convergence is separate
technical debt.

## Dynamic-regex regression

Entity and feature names known from Orion are embedded in generated predicates
by `generateUsesOldEntity` and `generateUsesField`. The remaining generic JPQL
helpers use constant regexes, capture identifiers, and compare the captures to
resolved declarations. A source/output scan found no regex constructed by
concatenating `Class.getName()` or `Field.getName()` into its pattern.

This preserves the optimization motivated by the earlier user-provided OpenMRS
observation:

| Observation supplied before V2 | Time |
|---|---:|
| Workflow with AST-dependent entity regex | 50 min 54 s |
| Workflow with literal `Visit` regex | 3 min 48 s |
| Build in the literal run | 1 min 45 s |
| Query compilation in the literal run | 20.4 s |
| Query evaluation in the literal run | 6 s |

Those figures were not rerun in this workspace and are not V2 experimental
results. They are retained only as regression motivation.

## CodeQL measurement protocol

`scripts/verify-v2.ps1` builds/tests the generator, compiles the fixture
project, emits all three modes, and records `performance.json`. When `codeql`
is available it also installs each generated pack and compiles every query. An
existing database can be passed with `-CodeqlDatabase`; alternatively,
`-CreateFixtureDatabase` builds a small fixture database. Raw SARIF is retained
inside each mode directory.

For PetClinic/OpenMRS runs, record separately:

1. Database creation wall time and commit under analysis.
2. Pack installation/query compilation wall time.
3. Query evaluation wall time per query and for the suite.
4. Complete workflow wall time.
5. Raw and normalized alert count.
6. Warm/cold cache state, CodeQL version, hardware, JDK, and repetitions.

Any query whose median evaluation time exceeds three times its V1 counterpart
must be investigated. The decision should also consider coverage benefit and
run-to-run variance; the ratio is a trigger, not an absolute rejection limit.

## Current blockers

- Generated QL has been structurally inspected and its APIs checked against
  the official Java library documentation, but it has not been compiled by a
  CodeQL CLI in this environment.
- Query evaluation, result counts, and SARIF correctness remain unvalidated.
- No formal PetClinic or OpenMRS campaign was launched, and neither repository
  nor its deployed generator JAR was modified.
