# OrionFlow V2 changelog

## Modular query libraries

- Split the generated library into `orion_java.qll`, `orion_spring.qll`,
  `orion_jpa.qll`, `orion_mongo.qll`, and `orion_dataflow.qll`.
- Retained `utils.qll` as the stable facade imported by operation queries.
- Added adapter-aware composition: JPA, MongoDB, or both can be emitted without
  duplicating the Java structural core.
- Kept names known during Orion generation as regular-expression literals and
  replaced AST-name-dependent patterns with constant captures plus equality.

## Configuration and compatibility

- Added `PersistenceFramework` with `jpa`, `mongo`, and `both`; JPA is the
  default when `--framework`/`-f` is omitted.
- Added an immutable generation profile for persistence-adapter selection.
- Removed `AnalysisMode` and `-m`/`--mode`; V2 always composes structural,
  selected framework semantics, and SCO-specific DataFlow.
- Retained only `-a ALL`/`--analysis ALL` as a deprecated no-op compatibility
  alias. Other analysis values are rejected.
- Made help usable without an input file and retained the current directory as
  the default output location.

## Structural Java detection

- Centralized resolved Java type references, constructor expressions, typed
  fields, JavaBeans accessors, resolved accessor calls, and type-dependent
  consumers in `orion_java.qll`.
- Removed the incompatible `creation.fromSource()` call from
  `ClassInstanceExpr`. `constructsEntity` now preserves the semantic condition
  `creation.getConstructedType() = entity`, which is valid for the target
  CodeQL Java library.
- Kept `TypeAccess.fromSource()` only on `TypeAccess`, where the API exists.

## Persistence adapters

- Moved dual `jakarta.persistence`/`javax.persistence`, JPQL, EntityManager,
  association, metadata, and physical join-name logic into `orion_jpa.qll`.
- Corrected relationship mapping so JPA physical names can be resolved through
  `@JoinTable`, direct `@JoinColumn`, nested join/inverse-join columns, and
  `referencedColumnName`.
- Added `orion_mongo.qll` for Spring Data MongoDB:
  - `@Document` and explicit collection names;
  - Java field names and `@Field` stored names;
  - `@Id`/`@MongoId`, `@DBRef`, and `@DocumentReference`;
  - `@Indexed`, `@CompoundIndex`, and `@CompoundIndexes`;
  - repository query strings and derived methods;
  - `MongoOperations`, `Criteria`, `Update`, and aggregation field-name APIs.
- Extracted persistence-independent Spring validation and repository-domain
  binding into `orion_spring.qll`.

## SCO generation

- Split the former monolithic query template into `EntityQuery`, `FeatureQuery`,
  `AttributeQuery`, and `RelationshipQuery`.
- Generated entity and field query predicates with Orion names embedded at
  generation time, avoiding the prior dynamic-regex performance pathology.
- Added dedicated query generation for Move Feature and Cast Reference instead
  of routing them through a different SCO template.
- Added MongoDB-aware Java/stored-name checks to entity, feature, relationship,
  cast, move, and promotion queries.
- Restricted DataFlow to Delete Feature, Cast Attribute, Cast Reference, Move
  Feature, and Delete Relationship. These queries use local, field-bound
  source/sink predicates and label flow-only findings as potential.

## Evolution sequencing

- Added stable logical identities for entities (`E…`), features (`F…`), and
  relationships (`R…`).
- Preserved those identities through entity/feature/relationship renames and
  feature moves.
- Added tombstones for deleted entities, features, and relationships so their
  original source identifiers remain resolvable during a chained evolution.
- Reset generator state for each transformation and process evolution blocks
  in source order.

## Tests and current validation

- Extended tests for framework parsing/composition, modular generation,
  framework-specific query content, selected DataFlow, dedicated move/reference
  templates, and chained/tombstoned evolution identities.
- Added Java/JPA/Spring and Spring Data MongoDB fixture coverage.
- The Maven test lifecycle passes.
- The current integration script generates 16 operation queries for each of the
  JPA, MongoDB, and `both` profiles; the no-flag profile is equivalent to JPA.
- The compatibility work used CodeQL CLI 2.27.2 and `codeql/java-all` 9.3.2.
  A partial compilation was completed before the final modular pass; complete
  compilation of all current profiles and query evaluation remain in progress.

## Scope safeguards

- No generated Java file is treated as source of truth; source changes live in
  Xtend/Java generator sources.
- No workflow, deployed generator JAR, application ground truth, or analysed
  PetClinic/OpenMRS source is changed by this refactoring.
- Global DataFlow, taint tracking, complete JPQL/JSON parsing, and dynamic query
  reconstruction remain outside the current scope.
