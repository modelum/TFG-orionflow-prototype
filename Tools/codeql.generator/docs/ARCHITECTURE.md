# OrionFlow V2 architecture

## Overview

OrionFlow V2 keeps one generated CodeQL pack per Orion evolution script, but
splits its predicates into physical modules. This prevents the structural Java
rules from being duplicated when JPA and MongoDB are selected together and
keeps DataFlow out of SCOs that do not need it.

The generation path is:

```text
Orion AST
  -> Orion2CodeQL + EvolutionContext
  -> Entity/Feature/Attribute/Relationship query templates + selected libraries
  -> operation .ql files + modular .qll files + suite/pack metadata
```

The generation profile carries the persistence-adapter composition. Structural
analysis, framework semantics, and SCO-selected DataFlow are always part of the
V2 generation contract. `Orion2CodeQL` processes operations in source order,
resolves their source-code identities through `EvolutionContext`, and delegates
to `EntityQuery`, `FeatureQuery`, `AttributeQuery`, or `RelationshipQuery`.

## Generated QL modules

| Module | Responsibility | Emission rule |
|---|---|---|
| `orion_java.qll` | Framework-independent Java declarations, resolved type references, constructor expressions, fields, accessors, calls, and type-dependent uses. | Always for a non-empty transformation. |
| `orion_spring.qll` | Spring rules shared by both persistence engines, including validation property calls and repository domain binding. | Always for a non-empty transformation. |
| `orion_jpa.qll` | JPA/JPQL and Spring Data JPA semantics, including `jakarta.persistence` and `javax.persistence`. | `--framework jpa` or `both`. |
| `orion_mongo.qll` | Spring Data MongoDB semantics for documents, stored names, repositories, query strings, mapping metadata, `MongoOperations`, Criteria, Update, and aggregation APIs. | `--framework mongo` or `both`. |
| `orion_dataflow.qll` | Source/sink-constrained `DataFlow::localFlow` helpers. | Always for a non-empty transformation; imported only by participating SCO queries. |
| `utils.qll` | Stable facade that imports the structural/shared modules and only the selected persistence adapters. Operation queries depend on this facade. | Always for a non-empty transformation. |

In `both` mode, `utils.qll` combines JPA and MongoDB alternatives. The Java and
Spring modules are generated once, not once per adapter.

## Framework profiles

`--framework jpa|mongo|both` controls adapter composition. `jpa` is the default,
so existing invocations that omit this flag retain their persistence behavior.

Every framework selection enables:

1. Structural Java impact detection.
2. Semantics for the selected persistence adapter or adapters.
3. Local DataFlow only in the five SCO templates listed below.

`AnalysisMode` and `-m`/`--mode` have been removed. `-a ALL`/`--analysis ALL`
is accepted only as a deprecated no-op for older invocations; it does not
select a different query set.

## Selective DataFlow

DataFlow is local and opt-in per SCO; there is no global flow or taint-tracking
configuration. The five participating operations are:

- Delete Feature: a value read from the deleted field reaches a dependent call.
- Cast Attribute: the old value reaches a consumer tied to the old type.
- Cast Reference: the old reference reaches a consumer tied to the old type.
- Move Feature: a value read from the source field reaches a dependent call.
- Delete Relationship: a relationship collection reaches a mutating collection
  or map operation.

Each rule binds the affected `Field` first, constrains its source to a resolved
field/getter read, and constrains its sink to the operation-specific consumer.
These findings are labelled as potential impacts. Other SCO queries do not
import `orion_dataflow.qll`.

## Evolution identity

`EvolutionContext` separates the logical identity of a schema element from its
current Orion name and its original source-code name:

- Entities receive stable IDs `E1`, `E2`, and so on.
- Features receive stable IDs `F1`, `F2`, and so on.
- Relationships receive stable IDs `R1`, `R2`, and so on.

Renames update the current name without changing the logical ID or original
name. Feature moves likewise retain the feature identity while changing its
current owner/name. Deletes create tombstones for entities, features, and
relationships, retaining the logical ID, original identity, last current name,
and deleted state. This lets a later operation in the same evolution sequence
continue to target identifiers that exist in the source CodeQL database rather
than names introduced only by earlier Orion operations.

## Query and library compatibility

Operation templates are split by responsibility into `EntityQuery`,
`FeatureQuery`, `AttributeQuery`, and `RelationshipQuery`. Names known by the
Orion generator are inserted into generated predicates as literals. Generic
helpers use constant regular expressions plus captured-value equality; they do
not construct a regular expression from `Class.getName()` or `Field.getName()`
at CodeQL evaluation time.

The Java construction predicate is compatible with CodeQL 2.27.2: it checks
`creation.getConstructedType() = entity` and does not call the unsupported
`ClassInstanceExpr.fromSource()` API. Source filtering remains on APIs that
exist for their actual QL types, such as `TypeAccess.fromSource()`.

## Build and validation tiers

The Maven lifecycle compiles Xtend/Java and executes the generator tests. That
tier currently passes. Generated output has also been checked at the generation
level: each framework profile produces the expected 16 operation queries for
the current integration script, and omission of `--framework` resolves to JPA.

The target QL environment is CodeQL CLI 2.27.2 with `codeql/java-all` 9.3.2.
A partial compatibility compilation was performed before the final modular
validation pass. Full compilation of all current JPA, MongoDB, and `both`
outputs, followed by query evaluation and result validation, is still in
progress and must not be inferred from the passing Maven tier.
