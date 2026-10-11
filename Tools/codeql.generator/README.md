# OrionFlow CodeQL Generator

OrionFlow transforms an Orion schema-evolution script into a CodeQL query pack
for Java applications. The generator separates framework-independent Java
impact detection from the selected persistence adapters. V3.2 adds bounded
call-graph propagation and query-local global DataFlow for CAST operations.

## Requirements

- JDK 11. The Maven build rejects newer JDKs before Xtend runs because
  Xtend/Xtext 2.25 cannot read JDK 21 bytecode reliably.
- Maven.
- For QL validation: CodeQL CLI 2.27.2 with `codeql/java-all` 9.3.2.

Build and run the unit/integration test suite with:

```shell
mvn clean test
```

`mvn test` is also safe and reproducible. Maven and the Eclipse/Xtend builder
share `src/main/generated-sources/xtend` as their generated-Java root, while
`target` contains only disposable compiled output. This prevents an IDE build
from replacing Maven classes with `Unresolved compilation problem` stubs.

Create the executable JAR with:

```shell
mvn clean package
```

## Command line

```shell
java -jar target/SpringDataJPA.predictor-3.2.0.jar \
  --input model/Prueba.orion \
  --output generated-query-pack \
  --framework jpa
```

`--framework` (or `-f`) accepts `jpa`, `mongo`, or `both`. If it is omitted,
the generator uses `jpa`, preserving the previous default.

Every invocation generates structural Java rules and the selected persistence
semantics. DataFlow and call-graph propagation are selected automatically by
the SCO; there is no public analysis-level flag. The old analysis modes have
been removed. `--analysis ALL` (or `-a ALL`) remains only as a deprecated,
no-op compatibility alias; new invocations should omit it.

Examples:

```shell
# Default adapter: JPA
java -jar target/SpringDataJPA.predictor-3.2.0.jar -i changes.orion -o out

# Spring Data MongoDB
java -jar target/SpringDataJPA.predictor-3.2.0.jar -i changes.orion -o out -f mongo

# One pack with both persistence adapters
java -jar target/SpringDataJPA.predictor-3.2.0.jar -i changes.orion -o out -f both
```

## Generated modules

Every non-empty generation includes `orion_java.qll`, `orion_spring.qll`,
`orion_dataflow.qll`, `orion_callgraph.qll`, and `utils.qll`. The generator
emits `orion_jpa.qll`, `orion_mongo.qll`, or both according to `--framework`.

- Local DataFlow is used by Delete Feature, Cast Attribute, Cast Reference,
  Move Feature, and Delete Relationship.
- Global DataFlow is generated only inside Cast Attribute and Cast Reference
  queries and is seeded by the exact entity/field literals of that SCO.
- Bounded call-graph propagation (one or two resolved edges) is used by Delete
  Feature, Move Feature, and Delete Relationship.

`utils.qll` is the stable facade imported by operation queries. In `both` mode
it composes both adapters while emitting the structural core only once.

See [the architecture](docs/ARCHITECTURE.md), [coverage matrix](docs/COVERAGE_MATRIX.md),
[V3.2 changes](docs/V3_2_CHANGES.md), and
[V3.2 test results](docs/V3_2_TEST_RESULTS.md) for details and validation
status. Performance observations and explicit boundaries are in
[V3.2 performance](docs/V3_2_PERFORMANCE.md) and
[V3.2 limitations](docs/V3_2_REMAINING_LIMITATIONS.md).
