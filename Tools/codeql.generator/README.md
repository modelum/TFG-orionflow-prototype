# OrionFlow CodeQL Generator

OrionFlow transforms an Orion schema-evolution script into a CodeQL query pack
for Java applications. Version 2 separates framework-independent Java impact
detection from the selected persistence adapters and from the small set of SCOs
that need local DataFlow.

## Requirements

- JDK 11.
- Maven.
- For QL validation: CodeQL CLI 2.27.2 with `codeql/java-all` 9.3.2.

Build and run the unit/integration test suite with:

```shell
mvn clean test
```

Create the executable JAR with:

```shell
mvn clean package
```

## Command line

```shell
java -jar target/SpringDataJPA.predictor-3.0.0.jar \
  --input model/Prueba.orion \
  --output generated-query-pack \
  --framework jpa
```

`--framework` (or `-f`) accepts `jpa`, `mongo`, or `both`. If it is omitted,
the generator uses `jpa`, preserving the previous default.

Every invocation generates structural Java rules, the selected persistence
semantics, and local DataFlow only for the five SCOs that opt into it. The old
analysis modes have been removed. `--analysis ALL` (or `-a ALL`) remains only
as a deprecated, no-op compatibility alias; new invocations should omit it.

Examples:

```shell
# Default adapter: JPA
java -jar target/SpringDataJPA.predictor-3.0.0.jar -i changes.orion -o out

# Spring Data MongoDB
java -jar target/SpringDataJPA.predictor-3.0.0.jar -i changes.orion -o out -f mongo

# One pack with both persistence adapters
java -jar target/SpringDataJPA.predictor-3.0.0.jar -i changes.orion -o out -f both
```

## Generated modules

Every non-empty generation includes `orion_java.qll`, `orion_spring.qll`, and
`utils.qll`. The generator emits `orion_jpa.qll`, `orion_mongo.qll`, or both
according to `--framework`. It also emits `orion_dataflow.qll`; only Delete
Feature, Cast Attribute, Cast Reference, Move
Feature, and Delete Relationship queries import and use it.

`utils.qll` is the stable facade imported by operation queries. In `both` mode
it composes both adapters while emitting the structural core only once.

See [the architecture](docs/ARCHITECTURE.md), [coverage matrix](docs/COVERAGE_MATRIX.md),
[V2 changelog](docs/CHANGELOG_ORIONFLOW_V2.md), and
[performance report](docs/PERFORMANCE_REPORT.md) for details and validation
status.
